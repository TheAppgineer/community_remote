use any_ascii::any_ascii;
use mediawiki::MediaWikiError;
use regex::Regex;
use serde_json::Value;

const API_URL: &'static str = "https://en.wikipedia.org/w/api.php";
const DISAMBIGUATION: &str = " (disambiguation)";

pub enum MediaHint {
    Artist,
    Album(String),
}

pub async fn get_extract(title: &str, ex_chars: u32, hint: &MediaHint) -> Option<String> {
    let results = search(title, hint).await;
    let title = match results {
        Some(results) if results.is_empty() => match hint {
            MediaHint::Album(_) => Some(format!("{title} (album)")),
            _ => None,
        },
        Some(results) => match disambiguate(&results, hint).await {
            Some(title) => Some(title),
            None => Some(results[0].to_owned()),
        },
        None => match hint {
            MediaHint::Album(_) => Some(format!("{title} (album)")),
            _ => None,
        },
    }?;
    let mut res = get_html_extract(&title, ex_chars).await.ok()?;

    if let Some(to_title) = res["query"]["normalized"][0]["to"].as_str() {
        res = get_html_extract(to_title, ex_chars).await.ok()?;
    }

    res["query"]["pages"][0]["extract"]
        .as_str()
        .map(|str| str.to_owned())
}

async fn disambiguate(titles: &[String], hint: &MediaHint) -> Option<String> {
    let mut matching: Option<String> = None;

    for title in titles {
        if let Some(wikitext) = get_wikitext(title).await {
            let mut music_header = None;
            let mut is_overview_page = false;
            let lines = wikitext.split('\n');
            let title = title.strip_suffix(DISAMBIGUATION).unwrap_or(title);

            for line in lines {
                if let Some((ref_level, _)) = music_header.as_ref() {
                    if line.starts_with('=') {
                        let level = line.chars().filter(|c| *c == '=').count() / 2;
                        if level <= *ref_level {
                            break;
                        }
                    }

                    const TITLE_SPLITTER: &'static str = r"\[\[([^\]]+)\]\]";
                    let regex = Regex::new(TITLE_SPLITTER).unwrap();

                    if let Some((_, [capture])) = regex.captures(line).map(|c| c.extract()) {
                        let (artist, album) = is_artist_or_album(capture, hint);

                        if capture.contains(title) && (artist || album) {
                            let option = capture.split('|').next()?.to_owned();
                            log::info!("Disambiguate option {}", option);

                            if by_artist(&option, hint).is_some() {
                                matching = Some(option);
                                break;
                            } else {
                                matching = match matching {
                                    Some(option) if option.contains("(album)") => Some(option),
                                    _ => Some(option),
                                };
                            }
                        }
                    }
                } else {
                    if line.contains(" may refer to:") || line.contains(" may also refer to:") {
                        is_overview_page = true;
                    }

                    music_header = if line.starts_with('=') {
                        if !is_overview_page {
                            break;
                        }

                        let level = line.chars().filter(|c| *c == '=').count() / 2;
                        let header = line.replace('=', "");

                        if header.contains("Music") || header.contains("Entertainment") {
                            Some((level, header))
                        } else {
                            None
                        }
                    } else {
                        None
                    }
                }
            }
        }
    }

    log::info!("Disambiguation {:?}", matching);
    matching
}

async fn search(search: &str, hint: &MediaHint) -> Option<Vec<String>> {
    let api = mediawiki::api::Api::new(API_URL).await.unwrap();

    let params = api.params_into(&[
        ("action", "query"),
        ("list", "search"),
        ("srsearch", search),
        ("srlimit", "20"),
        ("srprop", ""),
        ("utf8", ""),
    ]);

    let res = api.get_query_api_json(&params).await.unwrap();
    log::info!("Search results {}", res["query"]["search"]);

    let res = res["query"]["search"]
        .as_array()?
        .iter()
        .rev()
        .filter_map(|res| {
            let result = any_ascii(res["title"].as_str().unwrap())
                .to_lowercase()
                .replace(' ', "");
            let search = any_ascii(search).to_lowercase().replace(' ', "");
            let (artist, album) = is_artist_or_album(&result, hint);
            let album_disambiguation = match hint {
                MediaHint::Album(_) => result.contains("disambiguation"),
                _ => false,
            };

            if result == search
                || (result.starts_with(&search) && (album_disambiguation || artist || album))
            {
                res["title"].as_str().map(|str| str.to_owned())
            } else {
                None
            }
        })
        .collect::<Vec<_>>();

    log::info!("Selected {:?}", res);

    Some(res)
}

async fn get_html_extract(title: &str, ex_chars: u32) -> Result<Value, MediaWikiError> {
    let api = mediawiki::api::Api::new(API_URL).await.unwrap();

    let exchars = format!("{ex_chars}");
    let params = api.params_into(&[
        ("action", "query"),
        ("prop", "extracts"),
        ("titles", &any_ascii(title)),
        ("exchars", &exchars),
        ("exlimit", "1"),
        ("formatversion", "2"),
    ]);

    api.get_query_api_json(&params).await
}

async fn get_wikitext(title: &str) -> Option<String> {
    let api = mediawiki::api::Api::new(API_URL).await.unwrap();
    let rev_params = api.params_into(&[
        ("action", "parse"),
        ("prop", "wikitext"),
        ("page", title),
        ("formatversion", "2"),
    ]);
    let res = api.get_query_api_json(&rev_params).await.unwrap();

    if res["parse"]["title"] == title {
        Some(res["parse"]["wikitext"].as_str()?.to_owned())
    } else {
        None
    }
}

fn is_artist_or_album(title: &str, hint: &MediaHint) -> (bool, bool) {
    match hint {
        MediaHint::Artist if title.contains("band)") || title.contains("singer)") => (true, false),
        MediaHint::Album(artist) if title.contains(artist) || title.contains("album)") => {
            (false, true)
        }
        _ => (false, false),
    }
}

fn by_artist(title: &str, hint: &MediaHint) -> Option<()> {
    match hint {
        MediaHint::Album(artist) if title.contains(artist) => Some(()),
        MediaHint::Artist => Some(()),
        _ => None,
    }
}
