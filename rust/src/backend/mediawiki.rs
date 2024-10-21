use std::collections::HashMap;

use any_ascii::any_ascii;
use regex::Regex;
use serde::{Deserialize, Serialize};
use serde_json::Value;

const DISAMBIGUATION: &str = " (disambiguation)";

#[derive(Clone, Debug, Deserialize, Eq, Hash, PartialEq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum MediaHint {
    Artist,
    Album(String),
}

pub struct MediaWiki {
    country_code: String,
    api_url: String,
    cache: HashMap<String, String>,
    fallback: HashMap<String, String>,
    cache_changed: bool,
}

impl MediaWiki {
    pub fn new(country_code: &str, cache: Value, fallback: Value) -> Self {
        let api_url = format!("https://{}.wikipedia.org/w/api.php", country_code);
        let cache = serde_json::from_value::<HashMap<String, String>>(cache).unwrap_or_default();
        let fallback =
            serde_json::from_value::<HashMap<String, String>>(fallback).unwrap_or_default();

        Self {
            country_code: country_code.to_owned(),
            api_url,
            cache,
            fallback,
            cache_changed: false,
        }
    }

    pub async fn get_extract(&mut self, title: &str, hint: &MediaHint) -> Option<String> {
        let key = match hint {
            MediaHint::Artist => simplified(title),
            MediaHint::Album(artist) => simplified(&format!("{title}{artist}")),
        };
        let (country_code, page_title) = if let Some(page_title) = self.cache.get(&key) {
            (self.country_code.as_str(), page_title.to_owned())
        } else if let Some(page_title) = self.get_page_title(title, hint).await {
            self.cache.insert(key, page_title.to_owned());
            self.cache_changed = true;

            (self.country_code.as_str(), page_title)
        } else {
            ("en", self.fallback.get(&key)?.to_owned())
        };

        self.get_html_extract(country_code, &page_title).await
    }

    pub fn get_changed_cache(&mut self) -> Option<Value> {
        if self.cache_changed {
            self.cache_changed = false;

            Some(self.cache.serialize(serde_json::value::Serializer).unwrap())
        } else {
            None
        }
    }

    async fn get_page_title(&self, title: &str, hint: &MediaHint) -> Option<String> {
        let results = self.search(title, hint).await?;

        self.disambiguate(results, hint).await
    }

    async fn search(&self, search: &str, hint: &MediaHint) -> Option<Vec<String>> {
        const SUFFIX_SPLITTER: &'static str = r"^([(]*[^\[(]+)[(\[]+([^)]+)";
        let api = mediawiki::api::Api::new(&self.api_url).await.unwrap();
        let regex = Regex::new(SUFFIX_SPLITTER).unwrap();
        let (search, search_str) = match regex.captures(search).map(|c| c.extract::<2>()) {
            Some((_, captures)) if captures[1].ends_with(']') => {
                (captures[0].trim(), captures[0].trim().to_owned())
            }
            Some((_, captures)) => (
                captures[0].trim(),
                format!("{} AND {}", captures[0].trim(), captures[1]),
            ),
            _ => (search, search.to_owned()),
        };
        let search_str = match hint {
            MediaHint::Album(artist) if artist != "Various Artists" => {
                &format!("{search_str} AND {artist} AND album")
            }
            MediaHint::Album(_) => &format!("{search_str} AND album"),
            _ => &search_str,
        };
        let params = api.params_into(&[
            ("action", "query"),
            ("list", "search"),
            ("srsearch", search_str),
            ("srlimit", "20"),
            ("srprop", ""),
            ("utf8", ""),
        ]);
        let res = api.get_query_api_json(&params).await.unwrap();

        log::info!("Search term: {}", search_str);
        log::info!("Search results: {}", res["query"]["search"]);

        let mut res = res["query"]["search"]
            .as_array()?
            .iter()
            .filter_map(|res| {
                let result = simplified(res["title"].as_str().unwrap());
                let search = simplified(&search);
                let (artist_suffix, album_suffix) =
                    has_artist_or_album_suffix(&self.country_code, &result, hint);
                let album_disambiguation = result.contains("disambiguation");

                if result == search
                    || (result.starts_with(&search)
                        && (album_disambiguation
                            || artist_suffix
                            || album_suffix
                            || search.len() > 20))
                {
                    res["title"].as_str().map(|str| str.to_owned())
                } else {
                    None
                }
            })
            .collect::<Vec<_>>();
        let preference_suffixes: &[&str] = match hint {
            MediaHint::Artist => &["band)", "singer)"],
            MediaHint::Album(_) => &["album)", "soundtrack)"],
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

    async fn disambiguate(&self, mut titles: Vec<String>, hint: &MediaHint) -> Option<String> {
        const LINK_SPLITTER: &'static str = r"\[\[([^\]]+)\]\]";
        let regex = Regex::new(LINK_SPLITTER).unwrap();
        let overview = HashMap::from([
            ("en", vec![" may refer to:", " may also refer to:"]),
            ("nl", vec!["doorverwijspagina", " kan verwijzen naar:"]),
        ]);
        let music_headers = HashMap::from([
            ("en", vec!["music", "entertainment", "media", "other uses"]),
            ("nl", vec!["muziek"]),
        ]);
        let mut matching: Option<String> = None;
        let mut first_non_overview = None;

        if let MediaHint::Album(artist) = hint {
            if let Some(index) = titles.iter().position(|title| title == artist) {
                titles.remove(index);
            }
        }

        for (index, title) in titles.iter().enumerate() {
            let (artist_suffix, album_suffix) =
                has_artist_or_album_suffix(&self.country_code, title, hint);

            if artist_suffix || album_suffix {
                matching = Some(title.to_owned());
                break;
            }

            if let Some(wikitext) = self.get_wikitext(title).await {
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

                        if let Some((_, [capture])) = regex.captures(line).map(|c| c.extract()) {
                            let (artist_suffix, album_suffix) =
                                has_artist_or_album_suffix(&self.country_code, capture, hint);

                            if capture.starts_with(title) && (artist_suffix || album_suffix) {
                                let option = capture.split('|').next()?.to_owned();

                                if by_artist(&option, hint).is_some() {
                                    matching = Some(option);
                                    break;
                                } else {
                                    matching = match matching {
                                        Some(curr) if curr.ends_with("album)") => Some(curr),
                                        _ => Some(option),
                                    };
                                }
                            }
                        }
                    } else {
                        if let Some(overview) = overview.get(self.country_code.as_str()) {
                            for marker in overview {
                                if line.contains(marker) {
                                    is_overview_page = true;
                                }
                            }
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
                            let music_header = match music_headers.get(self.country_code.as_str()) {
                                Some(music_headers) => music_headers
                                    .iter()
                                    .find(|music_header| header.contains(**music_header))
                                    .is_some(),
                                _ => false,
                            };

                            if artist || music_header {
                                Some(level)
                            } else {
                                None
                            }
                        } else {
                            match regex.captures(line).map(|c| c.extract()) {
                                Some((_, [capture])) => {
                                    let (artist_suffix, album_suffix) = has_artist_or_album_suffix(
                                        &self.country_code,
                                        capture,
                                        hint,
                                    );

                                    if capture.starts_with(title) && (artist_suffix || album_suffix)
                                    {
                                        let option = capture.split('|').next()?.to_owned();

                                        if by_artist(&option, hint).is_some() {
                                            matching = Some(option);
                                            break;
                                        } else {
                                            matching = match matching {
                                                Some(curr) if curr.ends_with("album)") => {
                                                    Some(curr)
                                                }
                                                _ => Some(option),
                                            };
                                        }
                                    }

                                    matching.as_ref().map(|_| 0)
                                }
                                _ => None,
                            }
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

    async fn get_html_extract(&self, country_code: &str, title: &str) -> Option<String> {
        let api_url = format!("https://{}.wikipedia.org/w/api.php", country_code);
        let api = mediawiki::api::Api::new(&api_url).await.unwrap();
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

    async fn get_wikitext(&self, title: &str) -> Option<String> {
        let api = mediawiki::api::Api::new(&self.api_url).await.unwrap();
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
}

fn simplified(input: &str) -> String {
    let simplified = any_ascii(input)
        .to_lowercase()
        .replace(" + ", "and")
        .replace(" & ", "and")
        .replace(' ', "")
        .replace(':', "")
        .replace('-', "");

    if simplified.starts_with("the") {
        simplified.replace("the", "")
    } else {
        simplified
    }
}

fn has_artist_or_album_suffix(country_code: &str, title: &str, hint: &MediaHint) -> (bool, bool) {
    const SUFFIX_SPLITTER: &str = r"[^(]+\(([^)]+)";
    let title = &simplified(title);
    let artist_suffixes = HashMap::from([
        ("en", vec!["band", "singer"]),
        ("nl", vec!["band", "zanger"]),
    ]);
    let album_suffixes = HashMap::from([
        ("en", vec!["album", "soundtrack"]),
        ("nl", vec!["album", "soundtrack"]),
    ]);
    let song_suffixes = HashMap::from([("en", vec!["song"]), ("nl", vec!["single"])]);
    let regex = Regex::new(SUFFIX_SPLITTER).unwrap();
    let suffix = if let Some((_, [capture])) = regex.captures(title).map(|c| c.extract()) {
        &simplified(capture)
    } else {
        ""
    };

    fn is_suffix(country_code: &str, suffixes: HashMap<&str, Vec<&str>>, suffix: &str) -> bool {
        if let Some(suffixes) = suffixes.get(country_code) {
            suffixes
                .iter()
                .find(|sffx| suffix.ends_with(**sffx))
                .is_some()
        } else {
            false
        }
    }

    match hint {
        MediaHint::Artist if is_suffix(country_code, artist_suffixes, suffix) => (true, false),
        MediaHint::Album(artist)
            if (suffix.starts_with(&simplified(artist))
                || is_suffix(country_code, album_suffixes, suffix))
                && !is_suffix(country_code, song_suffixes, suffix)
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

    use simplelog::{format_description, ColorChoice, ConfigBuilder, TermLogger, TerminalMode};
    use time::UtcOffset;

    fn _init_log() {
        let time_format = format_description!("[hour]:[minute]:[second].[subsecond]");
        let seconds = chrono::Local::now().offset().local_minus_utc();
        let utc_offset = UtcOffset::from_whole_seconds(seconds).unwrap_or(UtcOffset::UTC);
        let config = ConfigBuilder::new()
            .set_time_format_custom(time_format)
            .set_time_offset(utc_offset)
            .build();

        let _ = TermLogger::init(
            log::LevelFilter::Info,
            config,
            TerminalMode::Stdout,
            ColorChoice::Never,
        );
    }

    #[tokio::test(flavor = "current_thread")]
    async fn artist_tests_en() {
        const ARTIST_TESTS: &[(&str, &str)] = &[
            ("Air", "Air (French band)"),
            ("Black", "Black (singer)"),
            ("BLØF", "BLØF"),
            ("Fish", "Fish (singer)"),
            ("Garbage", "Garbage (band)"),
            ("Kensington", "Kensington (band)"),
            ("Mike + the Mechanics", "Mike and the Mechanics"),
            ("Sam Brown", "Sam Brown (singer)"),
            ("Simon & Garfunkel", "Simon & Garfunkel"),
            (
                "Tom Petty & the Heartbreakers",
                "Tom Petty and the Heartbreakers",
            ),
            ("Tracy Chapman", "Tracy Chapman"),
        ];
        let mediawiki = MediaWiki::new("en", Value::Null, Value::Null);

        for test in ARTIST_TESTS {
            assert_eq!(
                Some(String::from(test.1)),
                mediawiki.get_page_title(test.0, &MediaHint::Artist).await
            );
        }
    }

    #[tokio::test(flavor = "current_thread")]
    async fn album_tests_en() {
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
            (
                "Great Subconscious Club",
                "K's Choice",
                "The Great Subconscious Club",
            ),
            ("Hotel California", "Eagles", "Hotel California (album)"),
            ("Stop!", "Sam Brown", "Stop! (album)"),
            (
                "The Common Linnets",
                "The Common Linnets",
                "The Common Linnets (album)",
            ),
            (
                "The Bodyguard [Original Soundtrack Album]",
                "Various Artists",
                "The Bodyguard (soundtrack)",
            ),
            ("Tracy Chapman", "Tracy Chapman", "Tracy Chapman (album)"),
        ];
        let mediawiki = MediaWiki::new("en", Value::Null, Value::Null);

        for test in ALBUM_TESTS {
            assert_eq!(
                Some(String::from(test.2)),
                mediawiki
                    .get_page_title(test.0, &MediaHint::Album(String::from(test.1)))
                    .await
            );
        }
    }

    #[tokio::test(flavor = "current_thread")]
    async fn artist_tests_nl() {
        const ARTIST_TESTS: &[(&str, &str)] = &[
            ("Air", "Air (Franse band)"),
            ("Black", "Black (zanger)"),
            ("BLØF", "BLØF"),
            ("Fish", "Fish (zanger)"),
            ("Garbage", "Garbage"),
            ("Kensington", "Kensington (band)"),
            ("Mike + the Mechanics", "Mike and the Mechanics"),
            ("Sam Brown", "Sam Brown"),
            ("Simon & Garfunkel", "Simon & Garfunkel"),
            (
                "Tom Petty & the Heartbreakers",
                "Tom Petty and the Heartbreakers",
            ),
            ("Tracy Chapman", "Tracy Chapman"),
        ];
        let mediawiki = MediaWiki::new("nl", Value::Null, Value::Null);

        for test in ARTIST_TESTS {
            assert_eq!(
                Some(String::from(test.1)),
                mediawiki.get_page_title(test.0, &MediaHint::Artist).await
            );
        }
    }

    #[tokio::test(flavor = "current_thread")]
    async fn album_tests_nl() {
        const ALBUM_TESTS: &[(&str, &str, &str)] = &[
            ("+", "Ed Sheeran", "+ (Ed Sheeran)"),
            (
                "1492: Conquest of Paradise [Music from the Original Soundtrack]",
                "Vangelis",
                "1492: Conquest of Paradise (soundtrack)",
            ),
            (
                "Across a Wire: Live in New York",
                "Counting Crows",
                "Across a Wire: Live in New York City",
            ),
            ("Hotel California", "Eagles", "Hotel California (album)"),
            (
                "The Common Linnets",
                "The Common Linnets",
                "The Common Linnets (album)",
            ),
            (
                "The Bodyguard [Original Soundtrack Album]",
                "Various Artists",
                "The Bodyguard (soundtrack)",
            ),
        ];
        let mediawiki = MediaWiki::new("nl", Value::Null, Value::Null);

        for test in ALBUM_TESTS {
            assert_eq!(
                Some(String::from(test.2)),
                mediawiki
                    .get_page_title(test.0, &MediaHint::Album(String::from(test.1)))
                    .await
            );
        }
    }
}
