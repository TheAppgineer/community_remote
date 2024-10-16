use rand::Rng;
use regex::Regex;
use roon_api::browse::Action as BrowseAction;
use roon_api::browse::Item as BrowseItem;
use roon_api::browse::ItemHint as BrowseItemHint;
use roon_api::browse::List as BrowseList;
use roon_api::browse::ListHint as BrowseListHint;
use roon_api::browse::LoadResult;
use roon_api::{
    browse::{BrowseOpts, LoadOpts},
    image::{Args, Image, Scale, Scaling},
    status::Status,
    transport::{
        volume::Mute, Control, QueueItem, QueueOperation, State, Transport, Zone, ZoneSeek,
    },
    CoreEvent, Parsed, RoonApi, RoonApiError,
};
use serde_json::Value;
use std::{
    collections::{HashMap, VecDeque},
    sync::{Arc, Mutex},
};
use tokio::sync::mpsc::Sender;

use crate::api::simple::{BrowseItems, ImageKeyValue, RoonEvent, ZoneSummary};

use super::browse_helper::BrowseHelper;
use super::mediawiki::{MediaHint, MediaWiki};
use super::roon_access::{RoonAccess, RoonAccessData};

pub const BROWSE_PAGE_SIZE: usize = 100;
pub const SESSION_ID: i32 = 0;
pub const COUNTRY_CODE: &'static str = "en";

pub struct RoonHandler {
    pub event_tx: Sender<RoonEvent>,
    pub browse: Option<BrowseHelper>,
    pub image: Option<Image>,
    pub transport: Option<Transport>,
    pub zone_map: HashMap<String, Zone>,
    pub zone_id: Option<String>,
    pub browse_id: Option<String>,
    pub browse_path: HashMap<String, Vec<String>>,
    pub browse_category: Option<i32>,
    pub browse_input: Option<String>,
    pub browse_offset: usize,
    pub browse_total: usize,
    pub browse_level: u32,
    pub artist_search: bool,
    pub pause_on_track_end: bool,
    pub pause_after_item_ids: Option<Vec<u32>>,
    pub services: Vec<String>,
    pub mediawiki: MediaWiki,
    mute_list: VecDeque<String>,
    status: Option<Status>,
    access: Option<Arc<Mutex<RoonAccess>>>,
    track_down_actionlist: bool,
    activate_profile: bool,
    api_token: Option<String>,
    config_path: Arc<String>,
    outputs: HashMap<String, String>,
    pop_levels: Option<u32>,
    queue: Option<Vec<QueueItem>>,
    about: Option<(String, MediaHint)>,
}

impl RoonHandler {
    pub fn new(
        event_tx: Sender<RoonEvent>,
        config_path: Arc<String>,
        country_code: &'static str,
        cache: Value,
    ) -> Self {
        Self {
            event_tx,
            browse: None,
            image: None,
            transport: None,
            zone_map: HashMap::new(),
            zone_id: None,
            browse_id: None,
            browse_path: HashMap::new(),
            browse_category: None,
            browse_input: None,
            browse_offset: 0,
            browse_total: 0,
            browse_level: 0,
            artist_search: false,
            pause_on_track_end: false,
            pause_after_item_ids: None,
            services: Vec::new(),
            mediawiki: MediaWiki::new(country_code, cache),
            mute_list: VecDeque::new(),
            status: None,
            access: None,
            track_down_actionlist: false,
            activate_profile: false,
            api_token: None,
            config_path,
            outputs: HashMap::new(),
            pop_levels: None,
            queue: None,
            about: None,
        }
    }

    pub fn set_access(&mut self, access: Arc<Mutex<RoonAccess>>) {
        self.access = Some(access);
    }

    pub fn get_multi_session_key(&self) -> Option<String> {
        Some(format!("{}-{}", self.api_token.as_deref()?, SESSION_ID))
    }

    pub async fn set_status_message(&self, message: String) {
        if let Some(status) = self.status.as_ref() {
            status.set_status(message, false).await;
        }
    }

    pub async fn handle_core_event(&mut self, core_event: CoreEvent) -> Option<()> {
        match core_event {
            CoreEvent::Discovered(mut core, token) => {
                self.status = core.get_status().cloned();
                self.set_status_message("Select Settings to setup access".to_owned())
                    .await;
                self.event_tx
                    .send(RoonEvent::CoreDiscovered(core.display_name, token))
                    .await
                    .unwrap();
            }
            CoreEvent::Registered(mut core, token) => {
                self.transport = core.get_transport().cloned();
                self.browse = Some(BrowseHelper::new(core.get_browse().cloned()?));
                self.image = core.get_image().cloned();

                self.zone_map.clear();
                self.outputs.clear();

                self.transport.as_ref()?.subscribe_zones().await;
                self.transport.as_ref()?.subscribe_outputs().await;

                self.browse_offset = 0;
                self.browse_category = None;
                self.browse_total = 0;
                self.browse.as_mut()?.browse_clear();

                self.event_tx
                    .send(RoonEvent::CoreRegistered(core.display_name, token))
                    .await
                    .unwrap();
            }
            CoreEvent::Lost(core) => {
                self.api_token = None;
                self.event_tx
                    .send(RoonEvent::CoreLost(core.display_name))
                    .await
                    .unwrap();
            }
            _ => (),
        }

        Some(())
    }

    pub async fn handle_msg_event(&mut self, msg: Option<(Value, Parsed)>) -> Option<()> {
        if let Some((_, parsed)) = msg {
            match parsed {
                Parsed::RoonState(roon_state) => {
                    self.api_token = roon_state
                        .tokens
                        .get(roon_state.paired_core_id.as_ref()?)
                        .cloned();

                    if let Err(err) = RoonApi::save_roon_state(&self.config_path, roon_state) {
                        log::warn!("Failed to save state: {err}");
                    }

                    let data = RoonApi::load_config(&self.config_path, "access");

                    if let Ok(data) = serde_json::from_value::<RoonAccessData>(data) {
                        self.access.as_ref()?.lock().unwrap().set_data(data);
                    }

                    self.query_profiles(true).await;
                }
                Parsed::SettingsSubscribed(_) => {
                    self.query_profiles(false).await;
                }
                Parsed::SettingsSaved(access) => {
                    match RoonApi::save_config(&self.config_path, "access", access.to_owned()) {
                        Err(err) => log::warn!("Failed to save access settings: {err}"),
                        Ok(()) => {
                            if let Ok(data) = serde_json::from_value::<RoonAccessData>(access) {
                                self.access.as_ref()?.lock().unwrap().set_data(data);
                                self.query_profiles(true).await;
                                self.send_zone_list().await;

                                let zone_id = self.zone_id.as_ref()?;

                                if self.has_blocked_output(zone_id) {
                                    self.event_tx
                                        .send(RoonEvent::ZoneChanged(None))
                                        .await
                                        .unwrap();
                                } else {
                                    let curr_zone =
                                        self.restrict_grouping_list(self.zone_map.get(zone_id)?);

                                    self.event_tx
                                        .send(RoonEvent::ZoneChanged(curr_zone))
                                        .await
                                        .unwrap();
                                }
                            }
                        }
                    }
                }
                Parsed::Zones(zones) => {
                    let mut curr_zone = None;
                    let prev_zone_state = if let Some(zone_id) = self.zone_id.as_deref() {
                        self.zone_map.iter().find_map(|(_, zone)| {
                            if zone.zone_id.as_str() == zone_id {
                                Some(zone.to_owned())
                            } else {
                                None
                            }
                        })
                    } else {
                        None
                    };

                    for zone in zones {
                        if Some(&zone.zone_id) == self.zone_id.as_ref() {
                            if !self.has_blocked_output(&zone.zone_id) {
                                curr_zone = self.restrict_grouping_list(&zone);

                                if prev_zone_state.is_none() {
                                    self.transport
                                        .as_ref()?
                                        .subscribe_queue(&zone.zone_id, 100)
                                        .await;
                                }
                            }
                        }
                        self.zone_map.insert(zone.zone_id.to_owned(), zone);
                    }

                    self.send_zone_list().await;

                    if let Some(zone) = curr_zone.as_ref() {
                        if let Some(prev_zone_state) = prev_zone_state {
                            if self.pause_on_track_end
                                && prev_zone_state.state == State::Playing
                                && zone.state == State::Paused
                            {
                                self.pause_on_track_end = false;

                                for output in &zone.outputs {
                                    self.transport
                                        .as_ref()?
                                        .mute(&output.output_id, &Mute::Unmute)
                                        .await;
                                }

                                self.event_tx
                                    .send(RoonEvent::PauseOnTrackEnd(false))
                                    .await
                                    .unwrap();
                            }

                            self.update_wikipedia_extract(&prev_zone_state, zone).await;

                            if let Some(value) = self.mediawiki.get_changed_cache() {
                                let path = self.config_path.replace("config", "wikipedia");

                                RoonApi::save_config(&path, COUNTRY_CODE, value).unwrap();
                            }
                        }

                        self.event_tx
                            .send(RoonEvent::ZoneChanged(curr_zone))
                            .await
                            .unwrap();
                    }
                }
                Parsed::ZonesRemoved(zone_ids) => {
                    for zone_id in &zone_ids {
                        self.zone_map.remove(zone_id);
                    }

                    self.send_zone_list().await;

                    if zone_ids.contains(self.zone_id.as_ref()?) {
                        self.event_tx
                            .send(RoonEvent::ZoneChanged(None))
                            .await
                            .unwrap();
                    }
                }
                Parsed::ZonesSeek(seeks) => {
                    let zone_id = self.zone_id.as_ref()?;

                    if !self.has_blocked_output(zone_id) {
                        let seek = seeks.iter().find(|seek| &seek.zone_id == zone_id)?;

                        self.handle_pause_on_track_end(seek).await;

                        self.event_tx
                            .send(RoonEvent::ZoneSeek(seek.to_owned()))
                            .await
                            .unwrap();
                    }
                }
                Parsed::Outputs(outputs) => {
                    for output in outputs {
                        self.outputs.insert(output.output_id, output.display_name);
                    }

                    self.handle_mute_list().await;
                    self.set_access_output_list();

                    self.event_tx
                        .send(RoonEvent::OutputsChanged(self.outputs.to_owned()))
                        .await
                        .unwrap();
                }
                Parsed::OutputsRemoved(output_ids) => {
                    for output_id in output_ids {
                        self.outputs.remove(&output_id);
                    }

                    self.set_access_output_list();

                    self.event_tx
                        .send(RoonEvent::OutputsChanged(self.outputs.to_owned()))
                        .await
                        .unwrap();
                }
                Parsed::BrowseResult(result, multi_session_key) => match result.action {
                    BrowseAction::List => {
                        self.browse.as_mut()?.browse_result().await;

                        if self.pop_levels.is_some() {
                            let opts = BrowseOpts {
                                multi_session_key,
                                pop_levels: self.pop_levels.take(),
                                ..Default::default()
                            };
                            self.browse.as_mut()?.browse(opts).await;
                        } else {
                            let offset = self.browse_offset;
                            let opts = LoadOpts {
                                count: Some(BROWSE_PAGE_SIZE),
                                offset,
                                multi_session_key,
                                set_display_offset: offset,
                                ..Default::default()
                            };

                            if self.browse_path.is_empty()
                                && (result.list.as_ref()?.title == "Explore"
                                    || result.list.as_ref()?.title == "Library")
                            {
                                self.browse_category = None;
                            }

                            self.browse_level = result.list.as_ref()?.level;
                            self.browse.as_mut()?.load(opts).await;
                        }
                    }
                    _ => {}
                },
                Parsed::LoadResult(result, multi_session_key) => {
                    self.on_load_results(result, multi_session_key).await;
                }
                Parsed::Queue(queue) => {
                    self.queue = Some(queue.to_owned());
                    self.event_tx
                        .send(RoonEvent::QueueItems(queue))
                        .await
                        .unwrap();
                }
                Parsed::QueueChanges(changes) => {
                    for change in changes {
                        match change.operation {
                            QueueOperation::Insert => {
                                let queue = self.queue.as_mut()?;

                                change.items?.iter().enumerate().for_each(|(index, item)| {
                                    queue.insert(change.index + index, item.to_owned());
                                });
                            }
                            QueueOperation::Remove => {
                                for _ in 0..change.count? {
                                    self.queue.as_mut()?.remove(change.index);
                                }
                            }
                        }
                    }

                    self.event_tx
                        .send(RoonEvent::QueueItems(self.queue.as_ref()?.to_owned()))
                        .await
                        .unwrap();
                }
                Parsed::Jpeg((image_key, image)) | Parsed::Png((image_key, image)) => {
                    let image_key_value = ImageKeyValue { image_key, image };

                    self.event_tx
                        .send(RoonEvent::Image(image_key_value))
                        .await
                        .unwrap();
                }
                Parsed::Error(err) => match err {
                    RoonApiError::BrowseInvalidItemKey(_)
                    | RoonApiError::BrowseInvalidLevels(_)
                    | RoonApiError::BrowseUnexpectedError(_) => {
                        self.browse_category = None;
                        self.browse.as_mut()?.browse_clear();
                        self.event_tx.send(RoonEvent::BrowseReset).await.unwrap();
                    }
                    RoonApiError::ImageUnexpectedError((_, image_key)) => {
                        let scaling = Some(Scaling::new(Scale::Stretch, 100, 100));
                        let args = Args::new(scaling, None);

                        self.image.as_ref()?.get_image(&image_key, args).await;
                    }
                    _ => {}
                },
                _ => (),
            }
        }

        Some(())
    }

    pub async fn select_zone(&mut self, zone_id: &str) -> Option<()> {
        if self.zone_id.as_deref() != Some(zone_id) {
            let zone = self.zone_map.get(zone_id);

            if !self.has_blocked_output(&zone_id) {
                self.zone_id = Some(zone_id.to_owned());

                if zone.is_some() {
                    self.transport.as_ref()?.subscribe_queue(zone_id, 100).await;
                }

                self.event_tx
                    .send(RoonEvent::ZoneChanged(self.restrict_grouping_list(zone?)))
                    .await
                    .unwrap();

                let now_playing = zone?.now_playing.as_ref()?;

                if now_playing.length.is_some() {
                    let title = now_playing.three_line.line3.as_str();
                    let artist = now_playing.three_line.line2.to_owned();
                    let extract = self
                        .mediawiki
                        .get_extract(title, &MediaHint::Album(artist))
                        .await?;

                    self.event_tx
                        .send(RoonEvent::WikiExtract(extract))
                        .await
                        .unwrap();
                }
            }
        }

        Some(())
    }

    pub async fn pause_whitelisted_outputs(&self) -> Option<()> {
        let output_ids = self.access.as_ref()?.lock().unwrap().get_output_ids()?;

        for output_id in output_ids {
            self.transport
                .as_ref()?
                .control(&output_id, &Control::Pause)
                .await;
        }

        Some(())
    }

    pub fn set_mute_list(&mut self) -> Option<()> {
        let zone_id = self.zone_id.as_ref()?;
        let outputs = &self.zone_map.get(zone_id)?.outputs;

        self.mute_list.clear();

        for output in outputs {
            self.mute_list.push_back(output.output_id.clone());
        }

        Some(())
    }

    pub async fn handle_mute_list(&mut self) -> Option<()> {
        let zone_id = self.zone_id.as_ref()?;
        let outputs = &self.zone_map.get(zone_id)?.outputs;

        loop {
            let output_id = self.mute_list.get(0)?;

            for output in outputs {
                if output.output_id == *output_id {
                    if let Some(volume) = output.volume.as_ref() {
                        let is_muted = volume.is_muted.unwrap_or(true);

                        if is_muted {
                            self.mute_list.pop_front();
                        } else {
                            self.transport.as_ref()?.mute(&output_id, &Mute::Mute).await;

                            return Some(());
                        }
                    } else {
                        self.mute_list.pop_front();
                    }

                    break;
                }
            }
        }
    }

    pub async fn select_browse_item(&mut self, item: BrowseItem) {
        let mut opts = BrowseOpts {
            item_key: item.item_key,
            multi_session_key: self.get_multi_session_key(),
            set_display_offset: Some(0),
            ..Default::default()
        };

        match item.hint {
            Some(BrowseItemHint::Action) => {
                // Only provide zone_id if zone is online
                opts.zone_or_output_id = self
                    .zone_id
                    .as_ref()
                    .filter(|zone_id| self.zone_map.contains_key(*zone_id))
                    .cloned();
            }
            Some(BrowseItemHint::ActionList) => {
                self.track_down_actionlist = true;
            }
            _ => {}
        }

        self.browse_offset = 0;
        if let Some(browse) = self.browse.as_mut() {
            browse.browse(opts).await;
        }
    }

    async fn on_load_results(
        &mut self,
        result: LoadResult,
        multi_session_key: Option<String>,
    ) -> Option<()> {
        let key = multi_session_key.as_deref()?;

        self.browse.as_mut()?.browse_result().await;

        if result.list.title == "Explore" {
            for item in &result.items {
                let title = item.title.to_owned();

                if !self.services.contains(&title)
                    && (title == "KKBOX" || title == "Qobuz" || title == "TIDAL")
                {
                    self.services.push(title);
                    self.event_tx
                        .send(RoonEvent::Services(self.services.to_owned()))
                        .await
                        .unwrap();
                }
            }
        }

        if let Some(path) = self.browse_path.get_mut(key) {
            if let Some(category) = path.pop() {
                let input = if category == "Search" {
                    self.browse_input.take()
                } else {
                    None
                };
                let item = result.items.iter().find(|item| item.title == *category)?;
                let (zone_id, pop_levels) = if item.hint == Some(BrowseItemHint::Action) {
                    // Only provide zone_id if zone is online
                    let zone_id = self
                        .zone_id
                        .as_ref()
                        .filter(|zone_id| self.zone_map.contains_key(*zone_id));

                    if result.list.title == "Play Album" {
                        (zone_id, Some(1))
                    } else {
                        (zone_id, None)
                    }
                } else {
                    (None, None)
                };

                self.browse_offset = 0;
                self.pop_levels = pop_levels;

                let opts = BrowseOpts {
                    input,
                    item_key: item.item_key.to_owned(),
                    multi_session_key,
                    set_display_offset: Some(self.browse_offset),
                    zone_or_output_id: zone_id.cloned(),
                    ..Default::default()
                };

                self.browse.as_mut()?.browse(opts).await;

                return Some(());
            }

            self.browse_path.remove(key);

            if result.list.title == "Profile" {
                let (profile, item_key) = self.process_profiles(&result.items).await?;
                let (access, profile_access) = {
                    let access = self.access.as_ref()?.lock().unwrap();

                    (access.has_data(), access.has_profile_access())
                };

                if access && self.activate_profile {
                    let opts = BrowseOpts {
                        item_key,
                        multi_session_key,
                        ..Default::default()
                    };

                    self.activate_profile = false;
                    self.browse.as_mut()?.browse(opts).await;

                    log::info!("Selected profile: {}", profile);
                    self.event_tx
                        .send(RoonEvent::CorePermitted(profile, profile_access))
                        .await
                        .unwrap();
                }

                return Some(());
            }
        }

        if result.list.title == "Explore"
            || result.list.title == "Library"
            || (self.artist_search && result.list.title == "Artists")
        {
            self.artist_search = false;
            self.browse_category = None;
            self.browse.as_mut()?.browse_clear();
            self.event_tx.send(RoonEvent::BrowseReset).await.unwrap();
        } else if self.browse_category.is_some() {
            let is_action_list = result.list.hint == Some(BrowseListHint::ActionList);

            if !is_action_list && self.track_down_actionlist {
                let opts = BrowseOpts {
                    item_key: result.items.get(0).as_ref()?.item_key.clone(),
                    multi_session_key,
                    ..Default::default()
                };

                self.browse.as_mut()?.browse(opts).await;
            } else {
                let event = if is_action_list {
                    self.track_down_actionlist = false;
                    RoonEvent::BrowseActions(result.items)
                } else {
                    let new_offset = result.offset + result.items.len();
                    let title = result.list.title.to_owned();

                    self.browse_id = multi_session_key;
                    self.browse_offset = new_offset;
                    self.browse_total = result.list.count;

                    let mut items = result.items;
                    let mut list = result.list;

                    let offset = if list.level == 2 && (title == "Albums" || title == "Tracks") {
                        if result.offset == 0 {
                            let len = title.len() - 1;
                            let title = &title[..len];

                            items = self.prepend_random_play_entry(title, &items)?;

                            result.offset
                        } else {
                            result.offset + 1
                        }
                    } else {
                        result.offset
                    } as u32;

                    for item in &mut items {
                        if let Some(subtitle) = item.subtitle.as_mut() {
                            if let Some(cleaned) = Self::cleanup_subtitle(subtitle) {
                                *subtitle = cleaned;
                            }
                        }
                    }

                    match title.as_str() {
                        "Search" | "Artists" | "Composers" => {
                            if list.subtitle.is_some() {
                                let old_len = items.len();

                                items = items
                                    .iter()
                                    .filter_map(|item| match item.subtitle.as_deref() {
                                        Some(subtitle) if subtitle == "0 Albums" => None,
                                        Some(subtitle) if subtitle == "0 Compositions" => None,
                                        _ => Some(item.to_owned()),
                                    })
                                    .collect::<Vec<_>>();

                                list.subtitle = if let Some(subtitle) = list.subtitle.as_mut() {
                                    Self::update_subtitle(subtitle, old_len, items.len())
                                } else {
                                    list.subtitle
                                }
                            }
                        }
                        "Settings" => {
                            if let Some(access) = &self.access {
                                let access = access.lock().unwrap();

                                if !access.has_profile_access() {
                                    let index =
                                        items.iter().position(|item| item.title == "Profile")?;

                                    items.remove(index);
                                }
                            }

                            for item in items.iter() {
                                if item.title == "Profile" {
                                    if let Some(subtitle) = item.subtitle.as_ref() {
                                        self.event_tx
                                            .send(RoonEvent::Profile(subtitle.to_owned()))
                                            .await
                                            .unwrap();
                                    }
                                }
                            }
                        }
                        _ => {
                            let item = items.get_mut(0)?;

                            if item.title == "Play Artist" || item.title == "Play Album" {
                                self.about = if item.title == "Play Album" {
                                    let artist = list.subtitle.as_ref()?.to_owned();

                                    Some((list.title.to_owned(), MediaHint::Album(artist)))
                                } else {
                                    Some((list.title.to_owned(), MediaHint::Artist))
                                };

                                item.title = format!("About {}", list.title);
                            }
                        }
                    }

                    let browse_items = BrowseItems {
                        list,
                        offset,
                        items,
                    };

                    RoonEvent::BrowseItems(browse_items)
                };

                self.event_tx.send(event).await.unwrap();
            }
        }

        Some(())
    }

    pub async fn get_about(&mut self) -> Option<()> {
        let (title, hint) = self.about.take()?;
        let extract = self
            .mediawiki
            .get_extract(&title, &hint)
            .await
            .unwrap_or_default();
        let list = BrowseList {
            title: format!("About {}", title),
            ..Default::default()
        };
        let item = BrowseItem {
            title: extract,
            ..Default::default()
        };
        let about = BrowseItems {
            list,
            offset: 0,
            items: vec![item],
        };
        self.event_tx.send(RoonEvent::About(about)).await.unwrap();

        Some(())
    }

    fn cleanup_subtitle(subtitle: &str) -> Option<String> {
        if subtitle.starts_with("[[") && subtitle.ends_with("]]") {
            const SUBTITLE_SPLITTER: &'static str = r"^\[\[[0-9]+\|([^\]]+)\]\][ /+]*";
            let regex = Regex::new(SUBTITLE_SPLITTER).unwrap();
            let mut results = vec![];
            let mut subtitle = subtitle;

            while !subtitle.is_empty() {
                subtitle = if let Some((match_str, [capture])) =
                    regex.captures(subtitle).map(|c| c.extract())
                {
                    results.push(capture);
                    subtitle.strip_prefix(match_str)
                } else {
                    None
                }?;
            }

            Some(results.join(", "))
        } else {
            None
        }
    }

    fn update_subtitle(subtitle: &str, old_len: usize, new_len: usize) -> Option<String> {
        let mut split = subtitle.split(' ');
        let mut subtitle = subtitle.to_owned();

        if let Ok(count) = split.next()?.parse::<usize>() {
            let mut remainder = split.next()?;

            if split.next().is_none() && count == old_len && new_len < old_len {
                if remainder.ends_with('s') && new_len == 1 {
                    remainder = &remainder[0..remainder.len() - 1];
                }
                subtitle = format!("{} {}", new_len, remainder);
            }
        }

        Some(subtitle)
    }

    async fn query_profiles(&mut self, activate_profile: bool) -> Option<()> {
        let path = vec!["Profile".to_owned(), "Settings".to_owned()];
        let multi_session_key = self.get_multi_session_key();

        self.browse_path
            .insert(multi_session_key.as_ref()?.to_owned(), path);

        let opts = BrowseOpts {
            multi_session_key,
            pop_all: true,
            set_display_offset: Some(0),
            ..Default::default()
        };

        self.activate_profile = activate_profile;
        self.browse_offset = 0;
        self.browse_category = None;
        self.browse_total = 0;
        self.browse.as_mut()?.browse(opts).await;

        Some(())
    }

    async fn process_profiles(&self, items: &[BrowseItem]) -> Option<(String, Option<String>)> {
        let mut access = self.access.as_ref()?.lock().unwrap();
        let assigned = access.get_profile();
        let profiles = items
            .iter()
            .map(|item| item.title.to_owned())
            .collect::<Vec<_>>();

        access.set_profiles(profiles);

        for item in items.iter() {
            match assigned {
                Some(assigned) if assigned == item.title => {
                    return Some((item.title.to_owned(), item.item_key.to_owned()));
                }
                Some(_) => continue,
                _ => {}
            }

            if let Some(subtitle) = item.subtitle.as_ref() {
                if subtitle == "selected" {
                    return Some((item.title.to_owned(), item.item_key.to_owned()));
                }
            }
        }

        None
    }

    fn set_access_output_list(&mut self) {
        if let Some(access) = self.access.as_mut() {
            let name_sort = |(a, _): &(String, String), (b, _): &(String, String)| a.cmp(b);
            let mut access = access.lock().unwrap();
            let mut outputs = self
                .outputs
                .iter()
                .map(|(output_id, display_name)| (display_name.to_owned(), output_id.to_owned()))
                .collect::<Vec<_>>();

            outputs.sort_by(name_sort);
            access.set_output_list(&outputs);
        }
    }

    fn has_blocked_output(&self, zone_id: &str) -> bool {
        if let Some(zone) = self.zone_map.get(zone_id) {
            if let Some(access) = self.access.as_ref() {
                let whitelist = access.lock().unwrap().get_output_ids();

                for output in &zone.outputs {
                    match whitelist {
                        Some(whitelist) if !whitelist.contains(&output.output_id) => {
                            return true;
                        }
                        _ => {}
                    }
                }

                return false;
            }
        }

        true
    }

    fn restrict_grouping_list(&self, zone: &Zone) -> Option<Zone> {
        let mut zone = zone.to_owned();
        let access = self.access.as_ref()?;

        if let Some(allowed_ids) = access.lock().unwrap().get_output_ids() {
            let prim_output = zone.outputs.get_mut(0)?;

            prim_output.can_group_with_output_ids = prim_output
                .can_group_with_output_ids
                .iter()
                .filter_map(|output_id| {
                    if allowed_ids.contains(output_id) {
                        Some(output_id.to_owned())
                    } else {
                        None
                    }
                })
                .collect();
        }

        Some(zone)
    }

    fn get_zone_summary(&self, zone: &Zone) -> Option<ZoneSummary> {
        let (image_key, now_playing) = if let Some(now_playing) = zone.now_playing.as_ref() {
            (
                now_playing.image_key.to_owned(),
                Some(now_playing.one_line.line1.to_owned()),
            )
        } else {
            (None, None)
        };

        if self.has_blocked_output(&zone.zone_id) {
            None
        } else {
            let output_ids = zone
                .outputs
                .iter()
                .map(|output| output.output_id.to_owned())
                .collect::<Vec<_>>();

            Some(ZoneSummary {
                zone_id: zone.zone_id.to_owned(),
                output_ids,
                display_name: zone.display_name.to_owned(),
                state: zone.state.to_owned(),
                now_playing,
                image_key,
            })
        }
    }

    async fn send_zone_list(&self) {
        let name_sort = |a: &ZoneSummary, b: &ZoneSummary| a.display_name.cmp(&b.display_name);
        let mut zones = self
            .zone_map
            .iter()
            .filter_map(|(_, zone)| self.get_zone_summary(zone))
            .collect::<Vec<_>>();

        zones.sort_by(name_sort);

        self.event_tx
            .send(RoonEvent::ZonesChanged(zones))
            .await
            .unwrap();
    }

    async fn handle_pause_on_track_end(&mut self, seek: &ZoneSeek) -> Option<()> {
        let zone_id = self.zone_id.as_deref()?;
        let zone = self.zone_map.get(zone_id)?;
        let queue_item_id = self.queue.as_ref()?.get(0)?.queue_item_id;
        let pause_after_item_id =
            if let Some(pause_after_item_ids) = self.pause_after_item_ids.as_ref() {
                pause_after_item_ids.contains(&queue_item_id)
            } else {
                false
            };

        if (self.pause_on_track_end || pause_after_item_id) && zone.state == State::Playing {
            let now_playing = zone.now_playing.as_ref()?;
            let length = now_playing.length? as i64;

            if length > 0 {
                let seek_position = seek.seek_position?;

                if seek_position == length {
                    for output in &zone.outputs {
                        self.transport
                            .as_ref()?
                            .mute(&output.output_id, &Mute::Mute)
                            .await;
                    }

                    self.pause_on_track_end = true
                } else if self.pause_on_track_end && seek.seek_position? == 0 {
                    self.transport
                        .as_ref()?
                        .control(&zone.zone_id, &Control::Stop)
                        .await;
                }
            }
        }

        Some(())
    }

    fn prepend_random_play_entry(
        &self,
        title: &str,
        items: &[BrowseItem],
    ) -> Option<Vec<BrowseItem>> {
        let offset = rand::thread_rng().gen_range(0..self.browse_total);
        let item_key = items.get(0)?.item_key.as_deref()?.split(':').next()?;
        let item_key = format!("{}:{}", item_key, offset);
        let item = BrowseItem {
            title: format!("Pick Random {title}"),
            subtitle: Some(format!("From a Total of {}", self.browse_total)),
            item_key: Some(format!("random_{}_{}", title, item_key)),
            hint: Some(BrowseItemHint::ActionList),
            ..Default::default()
        };

        Some([&[item], items].concat())
    }

    async fn update_wikipedia_extract(&mut self, prev: &Zone, curr: &Zone) -> Option<()> {
        let now_playing = curr.now_playing.as_ref()?;
        let prev = prev.now_playing.as_ref()?.three_line.line3.as_str();
        let curr = now_playing.three_line.line3.as_str();
        let artist = now_playing.three_line.line2.to_owned();

        if now_playing.length.is_some() && curr != prev {
            let extract = self
                .mediawiki
                .get_extract(&curr, &MediaHint::Album(artist))
                .await?;

            self.event_tx
                .send(RoonEvent::WikiExtract(extract))
                .await
                .unwrap();
        }

        Some(())
    }
}
