use any_ascii::any_ascii;
use mediawiki::MediaWikiError;
use regex::Regex;
use serde_json::Value;

const API_URL: &'static str = "https://en.wikipedia.org/w/api.php";
const DISAMBIGUATION: &str = " (disambiguation)";

#[derive(Debug)]
pub enum MediaHint {
    Artist,
    Album(String),
}

pub async fn get_extract(title: &str, hint: &MediaHint) -> Option<String> {
    const TITLE_SPLITTER: &'static str = r"^([(]*[^\[(]+)";
    let regex = Regex::new(TITLE_SPLITTER).unwrap();
    let title = match regex.captures(title).map(|c| c.extract()) {
        Some((_, [capture])) => capture,
        _ => title,
    };

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

    log::info!("Taking extract from: {title}");

    let mut res = get_html_extract(&title).await.ok()?;

    if let Some(to_title) = res["query"]["normalized"][0]["to"].as_str() {
        res = get_html_extract(to_title).await.ok()?;
    }

    res["query"]["pages"][0]["extract"]
        .as_str()
        .map(|str| str.to_owned())
}

async fn disambiguate(titles: &[String], hint: &MediaHint) -> Option<String> {
    let mut matching: Option<String> = None;
    let mut first_non_overview = None;

    for (index, title) in titles.iter().enumerate() {
        if let Some(wikitext) = get_wikitext(title).await {
            let mut music_header = None;
            let mut is_overview_page = false;
            let lines = wikitext.split('\n');
            let title = title.strip_suffix(DISAMBIGUATION).unwrap_or(title);

            for line in lines {
                if let Some(ref_level) = music_header.as_ref() {
                    if line.starts_with('=') {
                        let level = line.chars().filter(|c| *c == '=').count() / 2;
                        if level <= *ref_level {
                            break;
                        }
                    }

                    const LINK_SPLITTER: &'static str = r"\[\[([^\]]+)\]\]";
                    let regex = Regex::new(LINK_SPLITTER).unwrap();

                    if let Some((_, [capture])) = regex.captures(line).map(|c| c.extract()) {
                        let (artist, album) = has_artist_or_album_suffix(capture, hint);

                        if capture.contains(title) && (artist || album) {
                            let option = capture.split('|').next()?.to_owned();

                            if by_artist(&option, hint).is_some() {
                                matching = Some(option);
                                break;
                            } else {
                                matching = match matching {
                                    Some(option) if option.contains("album)") => Some(option),
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
                        let header = line.replace('=', "").to_lowercase();
                        let artist = match hint {
                            MediaHint::Artist => header.contains("people"),
                            _ => false,
                        };
                        println!("{}", line);

                        if artist
                            || header.contains("music")
                            || header.contains("entertainment")
                            || header.contains("media")
                        {
                            Some(level)
                        } else {
                            None
                        }
                    } else {
                        None
                    }
                }
            }

            if !is_overview_page && first_non_overview.is_none() {
                first_non_overview = Some(index);
            }
        }
    }

    if matching.is_none() {
        matching = titles.get(first_non_overview.unwrap_or(0)).cloned();
    }

    log::info!("Disambiguation: {}", matching.as_deref()?);
    matching
}

async fn search(search: &str, hint: &MediaHint) -> Option<Vec<String>> {
    let api = mediawiki::api::Api::new(API_URL).await.unwrap();
    let search_str = match hint {
        MediaHint::Album(artist) => &format!("{search} AND {artist} AND album"),
        _ => search,
    };

    let params = api.params_into(&[
        ("action", "query"),
        ("list", "search"),
        ("srsearch", search_str),
        ("srprop", ""),
        ("utf8", ""),
    ]);

    let res = api.get_query_api_json(&params).await.unwrap();
    log::info!("Search results: {}", res["query"]["search"]);

    let res = res["query"]["search"]
        .as_array()?
        .iter()
        .filter_map(|res| {
            let result = simplified(res["title"].as_str().unwrap());
            let search = simplified(search);
            let (artist_suffix, album_suffix) = has_artist_or_album_suffix(&result, hint);
            let album_disambiguation = result.contains("disambiguation");

            if result == search
                || (result.starts_with(&search)
                    && (album_disambiguation || artist_suffix || album_suffix))
            {
                res["title"].as_str().map(|str| str.to_owned())
            } else {
                None
            }
        })
        .rev()
        .collect::<Vec<_>>();

    log::info!("Selected: {:?}", res);

    Some(res)
}

async fn get_html_extract(title: &str) -> Result<Value, MediaWikiError> {
    let api = mediawiki::api::Api::new(API_URL).await.unwrap();

    let params = api.params_into(&[
        ("action", "query"),
        ("prop", "extracts"),
        ("titles", &any_ascii(title)),
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

fn simplified(input: &str) -> String {
    any_ascii(input).to_lowercase().replace(' ', "")
}

fn has_artist_or_album_suffix(title: &str, hint: &MediaHint) -> (bool, bool) {
    const SUFFIX_SPLITTER: &'static str = r"[^(]+\(([^)]+)";
    let regex = Regex::new(SUFFIX_SPLITTER).unwrap();
    let suffix = if let Some((_, [capture])) = regex.captures(title).map(|c| c.extract()) {
        capture
    } else {
        ""
    };

    match hint {
        MediaHint::Artist if suffix.ends_with("band") || suffix.ends_with("singer") => {
            (true, false)
        }
        MediaHint::Album(artist)
            if (suffix.contains(&simplified(artist)) || suffix.ends_with("album"))
                && !suffix.ends_with("song")
                && *title != simplified(artist) =>
        {
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
