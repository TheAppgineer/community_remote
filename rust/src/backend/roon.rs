use rand::Rng;
use roon_api::browse::Action as BrowseAction;
use roon_api::browse::Item as BrowseItem;
use roon_api::browse::ItemHint as BrowseItemHint;
use roon_api::browse::ListHint as BrowseListHint;
use roon_api::RoonApiError;
use roon_api::{
    browse::{Browse, BrowseOpts, LoadOpts},
    image::{Args, Image, Scale, Scaling},
    info,
    transport::{
        volume::{ChangeMode, Mute},
        Control, QueueItem, QueueOperation, State, Transport, Zone, ZoneSeek,
    },
    CoreEvent, Info, Parsed, RoonApi, Services, Svc,
};
use serde_json::Value;
use std::collections::VecDeque;
use std::{collections::HashMap, sync::Arc};
use tokio::{
    sync::{
        mpsc::{channel, Receiver, Sender},
        Mutex,
    },
    time::{sleep, Duration},
};

use crate::api::simple::{BrowseItems, ImageKeyValue, RoonEvent, ZoneSummary};

use super::browse_helper::BrowseHelper;

const BROWSE_PAGE_SIZE: usize = 100;

const PLAY_NOW: &str = "Play Now";
const ADD_NEXT: &str = "Add Next";
const QUEUE: &str = "Queue";

pub struct Roon {
    config_path: Arc<String>,
    handler: Arc<Mutex<RoonHandler>>,
}

struct RoonHandler {
    event_tx: Sender<RoonEvent>,
    api_token: Option<String>,
    config_path: Arc<String>,
    browse: Option<BrowseHelper>,
    image: Option<Image>,
    transport: Option<Transport>,
    zone_map: HashMap<String, Zone>,
    zone_id: Option<String>,
    mute_list: VecDeque<String>,
    outputs: HashMap<String, String>,
    browse_id: Option<String>,
    browse_path: HashMap<String, Vec<String>>,
    browse_category: i32,
    browse_input: Option<String>,
    browse_offset: usize,
    browse_total: usize,
    browse_level: u32,
    pop_levels: Option<u32>,
    artist_search: bool,
    queue: Option<Vec<QueueItem>>,
    pause_on_track_end: bool,
    pause_after_item_ids: Option<Vec<u32>>,
}

impl Roon {
    pub async fn start(config_path: String) -> (Roon, Receiver<RoonEvent>, String) {
        let (tx, rx) = channel::<RoonEvent>(10);
        let info = info!("com.theappgineer", "Community Remote");
        let mut roon = RoonApi::new(info);
        let config_path = Arc::new(config_path);
        let value = RoonApi::load_config(&config_path, "settings");
        let handler = Arc::new(Mutex::new(RoonHandler::new(tx, config_path.clone())));

        log::info!("Loading config from: {config_path}");

        let handler_clone = handler.clone();
        let config_path_clone = config_path.clone();
        tokio::spawn(async move {
            loop {
                let services = Some(vec![
                    Services::Browse(Browse::new()),
                    Services::Transport(Transport::new()),
                    Services::Image(Image::new()),
                ]);
                let provided: HashMap<String, Svc> = HashMap::new();
                let config_path = config_path_clone.clone();
                let get_roon_state = Box::new(move || RoonApi::load_roon_state(&config_path));

                if let Some((mut handlers, mut core_rx)) = roon
                    .start_discovery(get_roon_state, provided, services)
                    .await
                {
                    let roon_handler = handler_clone.clone();

                    roon_handler.lock().await.zone_id = None;

                    handlers.spawn(async move {
                        loop {
                            if let Some((core_event, msg)) = core_rx.recv().await {
                                let mut roon_handler = roon_handler.lock().await;

                                roon_handler.handle_core_event(core_event).await;
                                roon_handler.handle_msg_event(msg).await;
                            }
                        }
                    });

                    handlers.join_next().await;
                }

                sleep(Duration::from_secs(1)).await;
            }
        });

        let roon = Self {
            config_path,
            handler,
        };

        (roon, rx, value.to_string())
    }

    pub async fn get_image(&self, image_key: String) -> Option<()> {
        let handler = self.handler.lock().await;
        let scaling = Some(Scaling::new(Scale::Fill, 100, 100));
        let args = Args::new(scaling, None);

        handler.image.as_ref()?.get_image(&image_key, args).await;

        Some(())
    }

    pub async fn select_zone(&self, zone_id: &str) -> Option<()> {
        let mut handler = self.handler.lock().await;

        if handler.zone_id.as_deref() != Some(zone_id) {
            let zone = handler.zone_map.get(zone_id).cloned();

            handler.zone_id = Some(zone_id.to_owned());
            handler
                .transport
                .as_ref()?
                .subscribe_queue(zone_id, 100)
                .await;
            handler
                .event_tx
                .send(RoonEvent::ZoneChanged(zone))
                .await
                .unwrap();
        }

        Some(())
    }

    pub async fn browse_category(
        &self,
        category: i32,
        session_id: i32,
        input: Option<String>,
    ) -> Option<()> {
        let mut handler = self.handler.lock().await;

        if category != handler.browse_category {
            let category_paths = HashMap::from([
                (1, vec!["Search", "Library"]),
                (2, vec!["Artists", "Library"]),
                (3, vec!["Albums", "Library"]),
                (4, vec!["Tracks", "Library"]),
                (5, vec!["Genres"]),
                (6, vec!["Composers", "Library"]),
                (7, vec!["Tags", "Library"]),
                (8, vec!["My Live Radio"]),
                (9, vec!["Playlists"]),
                (11, vec!["Settings"]),
            ]);
            let multi_session_key = handler.get_multi_session_key(session_id);

            handler.browse_offset = 0;
            handler.browse_level = 0;
            handler.browse_total = 0;

            if let Some(path) = category_paths.get(&category) {
                let path = path
                    .iter()
                    .map(|str| String::from(*str))
                    .collect::<Vec<_>>();
                handler
                    .browse_path
                    .insert(multi_session_key.as_ref()?.to_owned(), path);
            }

            let opts = BrowseOpts {
                multi_session_key,
                pop_all: true,
                set_display_offset: Some(0),
                ..Default::default()
            };

            handler.browse.as_mut()?.browse(opts).await;
            handler.browse_category = category;
            handler.browse_input = input;
        }

        Some(())
    }

    pub async fn select_browse_item(&self, session_id: i32, item: BrowseItem) -> Option<()> {
        let item_key = item.item_key.as_deref()?;
        let multi_session_key = self.handler.lock().await.get_multi_session_key(session_id);

        if item_key.contains("random") {
            self.handle_random_item(multi_session_key, &item).await;
        } else {
            let mut handler = self.handler.lock().await;
            let mut opts = BrowseOpts {
                item_key: item.item_key,
                multi_session_key,
                set_display_offset: Some(0),
                ..Default::default()
            };

            if item.hint == Some(BrowseItemHint::Action) {
                opts.zone_or_output_id = handler.zone_id.to_owned();
            }

            handler.browse_offset = 0;
            handler.browse.as_mut()?.browse(opts).await;
        }

        Some(())
    }

    pub async fn browse_more(&self) -> Option<()> {
        let mut handler = self.handler.lock().await;

        if handler.browse_offset < handler.browse_total {
            // There are more items to load
            let opts = LoadOpts {
                count: Some(BROWSE_PAGE_SIZE),
                offset: handler.browse_offset,
                multi_session_key: handler.browse_id.to_owned(),
                set_display_offset: handler.browse_offset,
                ..Default::default()
            };

            let browse = handler.browse.as_mut()?;
            browse.load(opts).await;

            // Prevent additional loading till response is received
            handler.browse_offset = handler.browse_total;
        }

        Some(())
    }

    pub async fn browse_back(&self, session_id: i32) -> Option<()> {
        let mut handler = self.handler.lock().await;

        if handler.browse_level > 0 {
            let multi_session_key = handler.get_multi_session_key(session_id);
            let opts = BrowseOpts {
                multi_session_key,
                pop_levels: Some(1),
                ..Default::default()
            };

            handler.browse_offset = 0;

            let browse = handler.browse.as_mut()?;
            browse.browse(opts).await;
        }

        Some(())
    }

    pub async fn search_artist(&self, session_id: i32, artist: String) -> Option<()> {
        let path = vec![
            artist.to_owned(),
            "Artists".to_owned(),
            "Search".to_owned(),
            "Library".to_owned(),
        ];
        let mut handler = self.handler.lock().await;
        let multi_session_key = handler.get_multi_session_key(session_id);

        handler
            .browse_path
            .insert(multi_session_key.as_ref()?.to_owned(), path.clone());

        let opts = BrowseOpts {
            multi_session_key,
            pop_all: true,
            set_display_offset: Some(0),
            ..Default::default()
        };

        handler.browse.as_mut()?.browse(opts).await;
        handler.browse_offset = 0;
        handler.browse_level = 0;
        handler.artist_search = true;
        handler.browse_input = Some(artist);

        Some(())
    }

    pub async fn select_queue_item(&self, queue_item_id: u32) -> Option<()> {
        let handler = self.handler.lock().await;

        handler
            .transport
            .as_ref()?
            .play_from_here(handler.zone_id.as_deref()?, queue_item_id)
            .await;

        Some(())
    }

    pub async fn pause_after_queue_items(&self, queue_item_ids: Vec<u32>) {
        let mut handler = self.handler.lock().await;

        handler.pause_after_item_ids = Some(queue_item_ids);
    }

    pub async fn save(&self, settings: String) {
        let value = serde_json::from_str::<Value>(&settings).unwrap();

        if let Err(err) = RoonApi::save_config(&self.config_path, "settings", value) {
            log::warn!("Failed to save config: {err}");
        }

        self.handler
            .lock()
            .await
            .event_tx
            .send(RoonEvent::SettingsSaved)
            .await
            .unwrap();
    }

    pub async fn control(&self, control: &Control) -> Option<()> {
        let zone_id = self.handler.lock().await.zone_id.clone()?;

        self.control_by_zone_id(&zone_id, control).await;

        Some(())
    }

    pub async fn control_by_zone_id(&self, zone_id: &str, control: &Control) -> Option<()> {
        let handler = self.handler.lock().await;
        let zone = handler.zone_map.get(zone_id)?;

        let allowed = match control {
            Control::Play => zone.is_play_allowed,
            Control::Pause => zone.is_pause_allowed,
            Control::PlayPause => {
                zone.is_play_allowed || zone.is_pause_allowed || zone.state == State::Stopped
            }
            Control::Stop => zone.state == State::Playing || zone.state == State::Paused,
            Control::Next => zone.is_next_allowed,
            Control::Previous => zone.is_previous_allowed,
        };

        if allowed {
            handler.transport.as_ref()?.control(zone_id, control).await;
        }

        Some(())
    }

    pub async fn pause_all(&self) -> Option<()> {
        let handler = self.handler.lock().await;

        handler.transport.as_ref()?.pause_all().await;

        Some(())
    }

    pub async fn pause_on_track_end(&self) -> Option<()> {
        let mut handler = self.handler.lock().await;

        handler.pause_on_track_end = true;
        handler
            .event_tx
            .send(RoonEvent::PauseOnTrackEnd(true))
            .await
            .unwrap();

        Some(())
    }

    pub async fn mute(&self, output_id: &str, how: &Mute) -> Option<()> {
        let handler = self.handler.lock().await;

        handler.transport.as_ref()?.mute(output_id, how).await;

        Some(())
    }

    pub async fn mute_all(&self) -> Option<()> {
        let handler = self.handler.lock().await;

        handler.transport.as_ref()?.mute_all(&Mute::Mute).await;

        Some(())
    }

    pub async fn mute_zone(&self) -> Option<()> {
        let mut handler = self.handler.lock().await;
        let zone_id = handler.zone_id.as_ref()?;
        let outputs = &handler.zone_map.get(zone_id)?.outputs;
        let mut mute_list = VecDeque::new();

        for output in outputs {
            mute_list.push_back(output.output_id.clone());
        }

        handler.mute_list = mute_list;

        handler.handle_mute_list().await;

        Some(())
    }

    pub async fn change_volume(&self, output_id: &str, how: &ChangeMode, value: i32) -> Option<()> {
        let handler = self.handler.lock().await;

        handler
            .transport
            .as_ref()?
            .change_volume(&output_id, &how, value)
            .await;

        Some(())
    }

    pub async fn change_zone_volume(&self, how: &ChangeMode, value: i32) -> Option<()> {
        let handler = self.handler.lock().await;
        let zone_id = handler.zone_id.as_ref()?;
        let outputs = &handler.zone_map.get(zone_id)?.outputs;
        let transport = handler.transport.as_ref()?;

        for output in outputs {
            transport
                .change_volume(output.output_id.as_str(), &how, value)
                .await;
        }

        Some(())
    }

    pub async fn standby(&self, output_id: &str) -> Option<()> {
        let handler = self.handler.lock().await;

        handler.transport.as_ref()?.standby(output_id, None).await;

        Some(())
    }

    pub async fn group_outputs(&self, output_ids: Vec<String>) -> Option<()> {
        let output_ids = output_ids
            .iter()
            .map(|output_id| output_id.as_str())
            .collect::<Vec<_>>();
        let handler = self.handler.lock().await;

        for zone in handler.zone_map.values() {
            let current_ids = zone
                .outputs
                .iter()
                .map(|output| output.output_id.as_str())
                .collect::<Vec<_>>();
            let matches_all = output_ids.len() == current_ids.len()
                && output_ids.first() == current_ids.first()
                && output_ids
                    .iter()
                    .all(|output_id| current_ids.contains(output_id));
            let overlaps = current_ids
                .iter()
                .any(|current_id| output_ids.contains(current_id));

            if !matches_all && current_ids.len() > 1 && overlaps {
                handler
                    .transport
                    .as_ref()?
                    .ungroup_outputs(current_ids)
                    .await;
            }
        }

        if output_ids.len() > 1 {
            handler.transport.as_ref()?.group_outputs(output_ids).await;
        }

        Some(())
    }

    async fn handle_random_item(
        &self,
        multi_session_key: Option<String>,
        item: &BrowseItem,
    ) -> Option<()> {
        let mut handler = self.handler.lock().await;
        let item_key = item.item_key.as_deref()?;

        if item.hint == Some(BrowseItemHint::ActionList) {
            let actions = vec![
                BrowseItem {
                    title: "Play Now".to_owned(),
                    item_key: Some(format!("{}_playnow", item_key)),
                    hint: Some(BrowseItemHint::Action),
                    ..Default::default()
                },
                BrowseItem {
                    title: "Add Next".to_owned(),
                    item_key: Some(format!("{}_addnext", item_key)),
                    hint: Some(BrowseItemHint::Action),
                    ..Default::default()
                },
                BrowseItem {
                    title: "Queue".to_owned(),
                    item_key: Some(format!("{}_queue", item_key)),
                    hint: Some(BrowseItemHint::Action),
                    ..Default::default()
                },
            ];

            handler
                .event_tx
                .send(RoonEvent::BrowseActions(actions))
                .await
                .unwrap();
        } else {
            // random_item_key = "random_<type>_<item_key>_<action>"
            let fields = item_key.split('_').collect::<Vec<_>>();

            if fields.len() == 4 {
                let item_key = fields.get(2).map(|item_key| item_key.to_string());
                let mut path = vec![match *fields.get(3)? {
                    "playnow" => PLAY_NOW,
                    "addnext" => ADD_NEXT,
                    "queue" => QUEUE,
                    _ => PLAY_NOW,
                }];

                if fields[1] == "Album" {
                    path.push("Play Album")
                }

                let path = path
                    .iter()
                    .map(|str| String::from(*str))
                    .collect::<Vec<_>>();

                handler.browse_offset = 0;
                handler
                    .browse_path
                    .insert(multi_session_key.as_ref()?.to_owned(), path);

                let opts = BrowseOpts {
                    item_key,
                    multi_session_key,
                    ..Default::default()
                };

                handler.browse.as_mut()?.browse(opts).await;
            }
        }

        Some(())
    }
}

impl RoonHandler {
    fn new(event_tx: Sender<RoonEvent>, config_path: Arc<String>) -> Self {
        Self {
            event_tx,
            api_token: None,
            config_path,
            browse: None,
            image: None,
            transport: None,
            zone_map: HashMap::new(),
            zone_id: None,
            mute_list: VecDeque::new(),
            outputs: HashMap::new(),
            browse_id: None,
            browse_path: HashMap::new(),
            browse_category: 0,
            browse_input: None,
            browse_offset: 0,
            browse_total: 0,
            browse_level: 0,
            pop_levels: None,
            artist_search: false,
            queue: None,
            pause_on_track_end: false,
            pause_after_item_ids: None,
        }
    }

    fn get_multi_session_key(&self, session_id: i32) -> Option<String> {
        Some(format!("{}-{}", self.api_token.as_deref()?, session_id))
    }

    async fn handle_core_event(&mut self, core_event: CoreEvent) -> Option<()> {
        match core_event {
            CoreEvent::Found(mut core) => {
                self.transport = core.get_transport().cloned();
                self.browse = Some(BrowseHelper::new(core.get_browse().cloned()?));
                self.image = core.get_image().cloned();

                self.transport.as_ref()?.subscribe_zones().await;
                self.transport.as_ref()?.subscribe_outputs().await;

                self.browse_category = 0;
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

    async fn handle_msg_event(&mut self, msg: Option<(Value, Parsed)>) -> Option<()> {
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

                            if result.list.as_ref()?.title == "Explore"
                                || result.list.as_ref()?.title == "Library"
                            {
                                self.browse_category = 0;
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
                        || self.artist_search && result.list.title == "Artists"
                    {
                        self.artist_search = false;
                        self.browse_category = 0;
                        self.browse.as_mut()?.browse_clear();
                        self.event_tx.send(RoonEvent::BrowseReset).await.unwrap();
                    } else {
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
                            };

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
                    RoonApiError::BrowseInvalidItemKey(_) => {
                        self.browse_category = 0;
                        self.browse.as_mut()?.browse_clear();
                        self.event_tx.send(RoonEvent::BrowseReset).await.unwrap();
                    }
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

    async fn handle_mute_list(&mut self) -> Option<()> {
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
