use roon_api::{
    browse::{Action, Browse, BrowseOpts, LoadOpts},
    image::{Args, Image},
    info,
    transport::{Transport, Zone},
    CoreEvent, Info, Parsed, RoonApi, Services, Svc,
};
use serde_json::Value;
use std::{collections::HashMap, sync::Arc};
use tokio::sync::{
    mpsc::{channel, Receiver, Sender},
    Mutex,
};

use crate::api::{
    roon_browse_wrapper::BrowseItem,
    roon_transport_wrapper::{RoonZone, ZoneState},
    simple::{BrowseItems, ImageKeyValue, RoonEvent, ZoneSummary},
};

const CONFIG_PATH: &str = "config.json";
const BROWSE_PAGE_SIZE: usize = 20;

pub struct Roon {
    handler: Arc<Mutex<RoonHandler>>,
}

struct RoonHandler {
    event_tx: Sender<RoonEvent>,
    browse: Option<Browse>,
    browse_offset: usize,
    browse_total: usize,
    browse_level: u32,
    image: Option<Image>,
    transport: Option<Transport>,
    zone_map: HashMap<String, Zone>,
}

impl Roon {
    pub async fn start() -> (Roon, Receiver<RoonEvent>) {
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

        (roon, rx)
    }

    pub async fn get_image(&self, image_key: String, args: Args) -> Option<()> {
        let handler = self.handler.lock().await;

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

    pub async fn select_browse_item(&self, item_key: Option<String>) -> Option<()> {
        let mut handler = self.handler.lock().await;

        handler.browse_offset = 0;

        let browse = handler.browse.as_ref()?;
        let opts = BrowseOpts {
            item_key,
            set_display_offset: Some(handler.browse_offset),
            ..Default::default()
        };

        browse.browse(&opts).await;

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
                set_display_offset: handler.browse_offset,
                ..Default::default()
            };

            browse.load(&opts).await;

            // Prevent additional loading till response is received
            handler.browse_offset = handler.browse_total;
        }

        Some(())
    }

    pub async fn browse_back(&self) {
        let mut handler = self.handler.lock().await;

        if handler.browse_level > 0 {
            handler.browse_offset = 0;

            if let Some(browse) = handler.browse.as_ref() {
                let opts = BrowseOpts {
                    pop_levels: Some(1),
                    set_display_offset: Some(handler.browse_offset),
                    ..Default::default()
                };

                browse.browse(&opts).await;
            }
        }
    }
}

impl RoonHandler {
    fn new(event_tx: Sender<RoonEvent>) -> Self {
        Self {
            event_tx,
            browse: None,
            browse_offset: 0,
            browse_total: 0,
            browse_level: 0,
            image: None,
            transport: None,
            zone_map: HashMap::new(),
        }
    }

    async fn handle_core_event(&mut self, core_event: CoreEvent) -> Option<()> {
        match core_event {
            CoreEvent::Found(mut core) => {
                self.transport = core.get_transport().cloned();
                self.browse = core.get_browse().cloned();
                self.image = core.get_image().cloned();

                self.transport.as_ref()?.subscribe_zones().await;
                self.browse
                    .as_ref()?
                    .browse(&BrowseOpts {
                        pop_all: true,
                        ..Default::default()
                    })
                    .await;

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
                Parsed::BrowseResult(result, _) => match result.action {
                    Action::List => {
                        let offset = self.browse_offset;
                        let opts = LoadOpts {
                            count: Some(20),
                            offset,
                            set_display_offset: offset,
                            ..Default::default()
                        };

                        self.browse_level = result.list.as_ref()?.level;
                        self.browse.as_ref()?.load(&opts).await;
                    }
                    _ => {}
                },
                Parsed::LoadResult(result, _) => {
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
