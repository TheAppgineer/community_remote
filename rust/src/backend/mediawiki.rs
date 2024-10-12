use any_ascii::any_ascii;
use regex::Regex;

const API_URL: &'static str = "https://en.wikipedia.org/w/api.php";
const DISAMBIGUATION: &str = " (disambiguation)";

#[derive(Debug)]
pub enum MediaHint {
    Artist,
    Album(String),
}

pub async fn get_extract(title: &str, hint: &MediaHint) -> Option<String> {
    let title = get_page_title(title, hint).await?;

    get_html_extract(&title).await
}

async fn get_page_title(title: &str, hint: &MediaHint) -> Option<String> {
    let results = search(title, hint).await?;

    disambiguate(results, hint).await
}

async fn disambiguate(mut titles: Vec<String>, hint: &MediaHint) -> Option<String> {
    let mut matching: Option<String> = None;
    let mut first_non_overview = None;

    if let MediaHint::Album(artist) = hint {
        if let Some(index) = titles.iter().position(|title| title == artist) {
            titles.remove(index);
        }
    }

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
                        let (artist_suffix, album_suffix) =
                            has_artist_or_album_suffix(capture, hint);

                        if capture.contains(title) && (artist_suffix || album_suffix) {
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
    const SUFFIX_SPLITTER: &'static str = r"^([(]*[^\[(]+)[(\[]+([^)\]]+)";
    let api = mediawiki::api::Api::new(API_URL).await.unwrap();
    let regex = Regex::new(SUFFIX_SPLITTER).unwrap();
    let (search, search_str) = match regex.captures(search).map(|c| c.extract::<2>()) {
        Some((_, captures)) => (
            captures[0].trim(),
            format!("{} AND {}", captures[0].trim(), captures[1]),
        ),
        _ => (search, search.to_owned()),
    };
    let search_str = match hint {
        MediaHint::Album(artist) => &format!("{search_str} AND {artist} AND album"),
        _ => &search_str,
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

    let mut res = res["query"]["search"]
        .as_array()?
        .iter()
        .filter_map(|res| {
            let result = simplified(res["title"].as_str().unwrap());
            let search = simplified(&search);
            let (artist_suffix, album_suffix) = has_artist_or_album_suffix(&result, hint);
            let album_disambiguation = result.contains("disambiguation");

            if result == search
                || (result.starts_with(&search)
                    && (album_disambiguation || artist_suffix || album_suffix || search.len() > 20))
            {
                res["title"].as_str().map(|str| str.to_owned())
            } else {
                None
            }
        })
        .collect::<Vec<_>>();
    let preference_suffixes: &[&str] = match hint {
        MediaHint::Artist => &["band)", "singer)"],
        MediaHint::Album(_) => &["album)"],
    };

    for preference_suffix in preference_suffixes {
        if res
            .iter()
            .find(|title| title.starts_with(search) && title.contains(preference_suffix))
            .is_some()
        {
            if let Some(index) = res.iter().position(|title| title == search) {
                res.remove(index);
            }

            break;
        }
    }

    log::info!("Selected: {:?}", res);

    if res.is_empty() {
        None
    } else {
        Some(res)
    }
}

async fn get_html_extract(title: &str) -> Option<String> {
    let api = mediawiki::api::Api::new(API_URL).await.unwrap();
    let params = api.params_into(&[
        ("action", "query"),
        ("prop", "extracts"),
        ("titles", title),
        ("exlimit", "1"),
        ("formatversion", "2"),
    ]);
    let res = api.get_query_api_json(&params).await.ok()?;

    log::info!("Taking extract from: {title}");

    res["query"]["pages"][0]["extract"]
        .as_str()
        .map(|str| str.to_owned())
}

async fn get_wikitext(title: &str) -> Option<String> {
    let api = mediawiki::api::Api::new(API_URL).await.unwrap();
    let rev_params = api.params_into(&[
        ("action", "parse"),
        ("prop", "wikitext"),
        ("page", title),
        ("formatversion", "2"),
    ]);
    let res = api.get_query_api_json(&rev_params).await.ok()?;

    if res["parse"]["title"] == title {
        Some(res["parse"]["wikitext"].as_str()?.to_owned())
    } else {
        None
    }
}

fn simplified(input: &str) -> String {
    any_ascii(input)
        .to_lowercase()
        .replace(" + ", "and")
        .replace(" & ", "and")
        .replace(' ', "")
        .replace(':', "")
        .replace('-', "")
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

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test(flavor = "current_thread")]
    async fn artist_tests() {
        const ARTIST_TESTS: &[(&str, &str)] = &[
            ("Air", "Air (French band)"),
            ("Black", "Black (singer)"),
            ("BLØF", "BLØF"),
            ("Fish", "Fish (singer)"),
            ("Garbage", "Garbage (band)"),
            ("Mike + the Mechanics", "Mike and the Mechanics"),
            ("Sam Brown", "Sam Brown (singer)"),
            ("Simon & Garfunkel", "Simon & Garfunkel"),
            (
                "Tom Petty & the Heartbreakers",
                "Tom Petty and the Heartbreakers",
            ),
            ("Tracy Chapman", "Tracy Chapman"),
        ];

        for test in ARTIST_TESTS {
            assert_eq!(
                Some(String::from(test.1)),
                get_page_title(test.0, &MediaHint::Artist).await
            );
        }
    }

    #[tokio::test(flavor = "current_thread")]
    async fn album_tests() {
        const ALBUM_TESTS: &[(&str, &str, &str)] = &[
            ("+", "Ed Sheeran", "+ (album)"),
            ("101", "Depeche Mode", "101 (album)"),
            (
                "1492: Conquest of Paradise [Music from the Original Soundtrack]",
                "Vangelis",
                "1492: Conquest of Paradise (album)",
            ),
            (
                "Across a Wire: Live in New York",
                "Counting Crows",
                "Across a Wire: Live in New York City",
            ),
            (
                "Duran Duran (The Wedding Album)",
                "Duran Duran",
                "Duran Duran (1993 album)",
            ),
            (
                "From Time to Time: The Singles Collection",
                "Paul Young",
                "From Time to Time – The Singles Collection",
            ),
            ("Hotel California", "Eagles", "Hotel California (album)"),
            ("Stop!", "Sam Brown", "Stop! (album)"),
            (
                "The Common Linnets",
                "The Common Linnets",
                "The Common Linnets (album)",
            ),
            ("Tracy Chapman", "Tracy Chapman", "Tracy Chapman (album)"),
        ];

        for test in ALBUM_TESTS {
            assert_eq!(
                Some(String::from(test.2)),
                get_page_title(test.0, &MediaHint::Album(String::from(test.1))).await
            );
        }
    }
}
