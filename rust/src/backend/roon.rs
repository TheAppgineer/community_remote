use roon_api::{
    browse::{Action, Browse, BrowseOpts, LoadOpts},
    image::{Args, Image, Scale, Scaling},
    info,
    transport::{Transport, Zone},
    CoreEvent, Info, Parsed, RoonApi, Services, Svc,
};
use serde::Serialize;
use serde_json::Value;
use std::{collections::HashMap, sync::Arc};
use tokio::sync::{
    mpsc::{channel, Receiver, Sender},
    Mutex,
};

use crate::api::{
    roon_browse_wrapper::BrowseItem,
    roon_transport_wrapper::{RoonZone, ZoneState},
    simple::{BrowseItems, ImageKeyValue, RoonEvent, Settings, ZoneSummary},
};

const CONFIG_PATH: &str = "config.json";
const BROWSE_PAGE_SIZE: usize = 20;

pub struct Roon {
    handler: Arc<Mutex<RoonHandler>>,
}

struct RoonHandler {
    event_tx: Sender<RoonEvent>,
    browse: Option<Browse>,
    browse_id: Option<String>,
    browse_offset: usize,
    browse_total: usize,
    browse_level: u32,
    image: Option<Image>,
    transport: Option<Transport>,
    zone_map: HashMap<String, Zone>,
    browse_path: HashMap<String, Vec<&'static str>>,
}

impl Roon {
    pub async fn start() -> (Roon, Receiver<RoonEvent>, Settings) {
        let (tx, rx) = channel::<RoonEvent>(10);
        let info = info!("com.theappgineer", "Community Remote");
        let mut roon = RoonApi::new(info);
        let get_roon_state = Box::new(|| RoonApi::load_config(CONFIG_PATH, "roonstate"));
        let provided: HashMap<String, Svc> = HashMap::new();
        let services = Some(vec![
            Services::Browse(Browse::new()),
            Services::Transport(Transport::new()),
            Services::Image(Image::new()),
        ]);
        let handler = Arc::new(Mutex::new(RoonHandler::new(tx)));

        let handler_clone = handler.clone();
        tokio::spawn(async move {
            if let Some((mut handlers, mut core_rx)) = roon
                .start_discovery(get_roon_state, provided, services)
                .await
            {
                handlers.spawn(async move {
                    loop {
                        if let Some((core_event, msg)) = core_rx.recv().await {
                            let mut roon_handler = handler_clone.lock().await;

                            roon_handler.handle_core_event(core_event).await;
                            roon_handler.handle_msg_event(msg).await;
                        }
                    }
                });

                handlers.join_next().await;
            }
        });

        let roon = Self { handler };
        let value = RoonApi::load_config(CONFIG_PATH, "settings");
        let settings: Settings = serde_json::from_value(value).unwrap_or_default();

        (roon, rx, settings)
    }

    pub async fn get_image(&self, image_key: String, width: u32, height: u32) -> Option<()> {
        let handler = self.handler.lock().await;
        let scaling = Some(Scaling::new(Scale::Fill, width, height));
        let args = Args::new(scaling, None);

        handler.image.as_ref()?.get_image(&image_key, args).await;

        Some(())
    }

    pub async fn select_zone(&self, zone_id: &str) -> Option<()> {
        log::info!("Selecting zone: {zone_id}");
        let handler = self.handler.lock().await;
        let zone = RoonZone::new(handler.zone_map.get(zone_id).cloned()?);

        handler
            .event_tx
            .send(RoonEvent::ZoneSelected(zone))
            .await
            .unwrap();

        Some(())
    }

    pub async fn browse_category(&self, category: i32, session_id: i32) -> Option<()> {
        let mut handler = self.handler.lock().await;
        let category_paths = HashMap::from([
            (2, vec!["Playlists"]),
            (3, vec!["My Live Radio"]),
            (4, vec!["Genres"]),
            (6, vec!["Artists", "Library"]),
            (7, vec!["Albums", "Library"]),
            (8, vec!["Tracks", "Library"]),
            (9, vec!["Composers", "Library"]),
            (10, vec!["Tags", "Library"]),
            (12, vec!["Settings"]),
        ]);
        let multi_session_key = Some(session_id.to_string());
        let opts = BrowseOpts {
            multi_session_key,
            pop_all: true,
            set_display_offset: Some(0),
            ..Default::default()
        };

        handler.browse_offset = 0;

        if let Some(path) = category_paths.get(&category) {
            handler
                .browse_path
                .insert(session_id.to_string(), path.clone());
        }

        handler.browse.as_ref()?.browse(&opts).await;

        Some(())
    }

    pub async fn select_browse_item(
        &self,
        session_id: i32,
        item_key: Option<String>,
    ) -> Option<()> {
        let mut handler = self.handler.lock().await;

        handler.browse_offset = 0;

        let multi_session_key = Some(session_id.to_string());
        let opts = BrowseOpts {
            item_key,
            multi_session_key,
            set_display_offset: Some(0),
            ..Default::default()
        };

        handler.browse.as_ref()?.browse(&opts).await;

        Some(())
    }

    pub async fn browse_more(&self) -> Option<()> {
        let mut handler = self.handler.lock().await;

        if handler.browse_offset < handler.browse_total {
            // There are more items to load
            let browse = handler.browse.as_ref()?;
            let opts = LoadOpts {
                count: Some(BROWSE_PAGE_SIZE),
                offset: handler.browse_offset,
                multi_session_key: handler.browse_id.clone(),
                set_display_offset: handler.browse_offset,
                ..Default::default()
            };

            browse.load(&opts).await;

            // Prevent additional loading till response is received
            handler.browse_offset = handler.browse_total;
        }

        Some(())
    }

    pub async fn browse_back(&self, session_id: i32) -> Option<()> {
        let mut handler = self.handler.lock().await;

        if handler.browse_level > 0 {
            handler.browse_offset = 0;

            let browse = handler.browse.as_ref();
            let multi_session_key = Some(session_id.to_string());
            let opts = BrowseOpts {
                multi_session_key,
                pop_levels: Some(1),
                set_display_offset: Some(0),
                ..Default::default()
            };

            browse.as_ref()?.browse(&opts).await;
        }

        Some(())
    }

    pub async fn save(&self, settings: Settings) {
        let value = settings.serialize(serde_json::value::Serializer).unwrap();

        RoonApi::save_config(CONFIG_PATH, "settings", value).unwrap();

        self.handler
            .lock()
            .await
            .event_tx
            .send(RoonEvent::Settings(settings))
            .await
            .unwrap();
    }
}

impl RoonHandler {
    fn new(event_tx: Sender<RoonEvent>) -> Self {
        Self {
            event_tx,
            browse: None,
            browse_id: None,
            browse_offset: 0,
            browse_total: 0,
            browse_level: 0,
            image: None,
            transport: None,
            zone_map: HashMap::new(),
            browse_path: HashMap::new(),
        }
    }

    async fn handle_core_event(&mut self, core_event: CoreEvent) -> Option<()> {
        match core_event {
            CoreEvent::Found(mut core) => {
                self.transport = core.get_transport().cloned();
                self.browse = core.get_browse().cloned();
                self.image = core.get_image().cloned();

                self.transport.as_ref()?.subscribe_zones().await;

                self.event_tx
                    .send(RoonEvent::CoreFound(core.display_name))
                    .await
                    .unwrap();
            }
            CoreEvent::Lost(core) => {
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
        if let Some((raw, parsed)) = msg {
            match parsed {
                Parsed::RoonState => {
                    RoonApi::save_config(CONFIG_PATH, "roonstate", raw).unwrap();
                }
                Parsed::Zones(zones) => {
                    for zone in zones {
                        self.zone_map.insert(zone.zone_id.to_owned(), zone);
                    }

                    self.send_zone_list().await;
                }
                Parsed::ZonesRemoved(zone_ids) => {
                    for zone_id in &zone_ids {
                        self.zone_map.remove(zone_id);
                    }

                    self.send_zone_list().await;
                }
                Parsed::BrowseResult(result, multi_session_key) => match result.action {
                    Action::List => {
                        let offset = self.browse_offset;
                        let opts = LoadOpts {
                            count: Some(20),
                            offset,
                            multi_session_key,
                            set_display_offset: offset,
                            ..Default::default()
                        };

                        self.browse_level = result.list.as_ref()?.level;
                        self.browse.as_ref()?.load(&opts).await;
                    }
                    _ => {}
                },
                Parsed::LoadResult(result, multi_session_key) => {
                    let key = multi_session_key.as_deref()?;

                    if let Some(path) = self.browse_path.get_mut(key) {
                        if let Some(category) = path.pop() {
                            let item_key = result.items.iter().find_map(|item| {
                                if item.title == *category {
                                    item.item_key.as_ref()
                                } else {
                                    None
                                }
                            });
                            self.browse_offset = 0;
                            let opts = BrowseOpts {
                                item_key: item_key.cloned(),
                                multi_session_key,
                                set_display_offset: Some(self.browse_offset),
                                ..Default::default()
                            };

                            self.browse.as_ref()?.browse(&opts).await;

                            return Some(());
                        }

                        self.browse_path.remove(key);
                    }

                    let new_offset = result.offset + result.items.len();
                    let browse_items = result
                        .items
                        .iter()
                        .map(|inner| BrowseItem::new(inner.to_owned()))
                        .collect();
                    let browse_items = BrowseItems {
                        title: result.list.title,
                        level: result.list.level,
                        offset: result.offset,
                        total: result.list.count,
                        items: browse_items,
                    };

                    self.browse_id = multi_session_key;
                    self.browse_offset = new_offset;
                    self.browse_total = result.list.count;

                    self.event_tx
                        .send(RoonEvent::BrowseItems(browse_items))
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

                ZoneSummary {
                    zone_id: zone_id.to_owned(),
                    display_name: zone.display_name.to_owned(),
                    state: ZoneState::from(zone.state.to_owned()),
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
}
