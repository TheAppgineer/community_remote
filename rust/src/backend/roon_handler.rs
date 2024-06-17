use rand::Rng;
use roon_api::browse::Action as BrowseAction;
use roon_api::browse::Item as BrowseItem;
use roon_api::browse::ItemHint as BrowseItemHint;
use roon_api::browse::ListHint as BrowseListHint;
use roon_api::{
    browse::{BrowseOpts, LoadOpts},
    image::{Args, Image, Scale, Scaling},
    transport::{
        volume::Mute, Control, QueueItem, QueueOperation, State, Transport, Zone, ZoneSeek,
    },
    CoreEvent, Parsed, RoonApi, RoonApiError,
};
use serde_json::Value;
use std::{
    collections::{HashMap, VecDeque},
    sync::Arc,
};
use tokio::sync::mpsc::Sender;

use crate::api::simple::{BrowseItems, ImageKeyValue, RoonEvent, ZoneSummary};

use super::browse_helper::BrowseHelper;

pub const BROWSE_PAGE_SIZE: usize = 100;

pub struct RoonHandler {
    pub event_tx: Sender<RoonEvent>,
    pub browse: Option<BrowseHelper>,
    pub image: Option<Image>,
    pub transport: Option<Transport>,
    pub zone_map: HashMap<String, Zone>,
    pub zone_id: Option<String>,
    pub mute_list: VecDeque<String>,
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
    api_token: Option<String>,
    config_path: Arc<String>,
    outputs: HashMap<String, String>,
    pop_levels: Option<u32>,
    queue: Option<Vec<QueueItem>>,
}

impl RoonHandler {
    pub fn new(event_tx: Sender<RoonEvent>, config_path: Arc<String>) -> Self {
        Self {
            event_tx,
            browse: None,
            image: None,
            transport: None,
            zone_map: HashMap::new(),
            zone_id: None,
            mute_list: VecDeque::new(),
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
            api_token: None,
            config_path,
            outputs: HashMap::new(),
            pop_levels: None,
            queue: None,
        }
    }

    pub fn get_multi_session_key(&self, session_id: i32) -> Option<String> {
        Some(format!("{}-{}", self.api_token.as_deref()?, session_id))
    }

    pub async fn handle_core_event(&mut self, core_event: CoreEvent) -> Option<()> {
        match core_event {
            CoreEvent::Found(mut core) => {
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
                    .send(RoonEvent::CoreFound(core.display_name))
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
                            curr_zone = Some(zone.to_owned());

                            if prev_zone_state.is_none() {
                                self.transport
                                    .as_ref()?
                                    .subscribe_queue(&zone.zone_id, 100)
                                    .await;
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
                    let seek = seeks.iter().find(|seek| &seek.zone_id == zone_id)?;

                    self.handle_pause_on_track_end(seek).await;

                    self.event_tx
                        .send(RoonEvent::ZoneSeek(seek.to_owned()))
                        .await
                        .unwrap();
                }
                Parsed::Outputs(outputs) => {
                    for output in outputs {
                        self.outputs.insert(output.output_id, output.display_name);
                    }

                    self.handle_mute_list().await;

                    self.event_tx
                        .send(RoonEvent::OutputsChanged(self.outputs.to_owned()))
                        .await
                        .unwrap();
                }
                Parsed::OutputsRemoved(output_ids) => {
                    for output_id in output_ids {
                        self.outputs.remove(&output_id);
                    }

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
                            let (zone_id, pop_levels) = if item.hint == Some(BrowseItemHint::Action)
                            {
                                if result.list.title == "Play Album" {
                                    (self.zone_id.as_ref(), Some(1))
                                } else {
                                    (self.zone_id.as_ref(), None)
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
                    }

                    if result.list.title == "Explore"
                        || result.list.title == "Library"
                        || (self.artist_search && result.list.title == "Artists")
                    {
                        self.artist_search = false;
                        self.browse_category = None;
                        self.browse.as_mut()?.browse_clear();
                        self.event_tx.send(RoonEvent::BrowseReset).await.unwrap();
                    } else {
                        if result.list.title == "Settings" {
                            for item in result.items.iter() {
                                if item.title == "Profile" {
                                    if let Some(subtitle) = item.subtitle.as_ref() {
                                        self.event_tx
                                            .send(RoonEvent::Profile(subtitle.to_owned()))
                                            .await
                                            .unwrap();
                                        break;
                                    }
                                }
                            }
                        }

                        if self.browse_category.is_some() {
                            let event = if result.list.hint == Some(BrowseListHint::ActionList) {
                                RoonEvent::BrowseActions(result.items)
                            } else {
                                let new_offset = result.offset + result.items.len();
                                let title = result.list.title.to_owned();

                                self.browse_id = multi_session_key;
                                self.browse_offset = new_offset;
                                self.browse_total = result.list.count;

                                let mut items = result.items;

                                let offset = if title == "Albums" || title == "Tracks" {
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

                                let browse_items = BrowseItems {
                                    list: result.list,
                                    offset,
                                    items,
                                };

                                RoonEvent::BrowseItems(browse_items)
                            };

                            self.event_tx.send(event).await.unwrap();
                        }
                    }
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
                    | RoonApiError::BrowseInvalidLevels(_) => {
                        self.browse_category = None;
                        self.browse.as_mut()?.browse_clear();
                        self.event_tx.send(RoonEvent::BrowseReset).await.unwrap();
                    }
                    RoonApiError::BrowseUnexpectedError(_) => {}
                    RoonApiError::ImageUnexpectedError((_, image_key)) => {
                        let scaling = Some(Scaling::new(Scale::Stretch, 100, 100));
                        let args = Args::new(scaling, None);

                        self.image.as_ref()?.get_image(&image_key, args).await;
                    }
                },
                _ => (),
            }
        }

        Some(())
    }

    async fn send_zone_list(&self) {
        let name_sort = |a: &ZoneSummary, b: &ZoneSummary| a.display_name.cmp(&b.display_name);
        let mut zones = self
            .zone_map
            .iter()
            .map(|(zone_id, zone)| {
                let (image_key, now_playing) = if let Some(now_playing) = zone.now_playing.as_ref()
                {
                    (
                        now_playing.image_key.to_owned(),
                        Some(now_playing.one_line.line1.to_owned()),
                    )
                } else {
                    (None, None)
                };

                let output_ids = zone
                    .outputs
                    .iter()
                    .map(|output| output.output_id.to_owned())
                    .collect::<Vec<_>>();

                ZoneSummary {
                    zone_id: zone_id.to_owned(),
                    output_ids,
                    display_name: zone.display_name.to_owned(),
                    state: zone.state.to_owned(),
                    now_playing,
                    image_key,
                }
            })
            .collect::<Vec<_>>();

        zones.sort_by(name_sort);

        self.event_tx
            .send(RoonEvent::ZonesChanged(zones))
            .await
            .unwrap();
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
}
