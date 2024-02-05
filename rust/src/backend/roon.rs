use roon_api::{
    browse::Browse,
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

use crate::api::roon_transport_wrapper::{RoonZone, ZoneState};
use crate::api::simple::RoonEvent;

const CONFIG_PATH: &str = "config.json";

pub struct ZoneSummary {
    pub zone_id: String,
    pub display_name: String,
    pub state: ZoneState,
    pub now_playing: Option<String>,
    pub image_key: Option<String>,
}

pub struct Roon {
    handler: Arc<Mutex<RoonHandler>>,
}

struct RoonHandler {
    event_tx: Sender<RoonEvent>,
    browse: Option<Browse>,
    image: Option<Image>,
    transport: Option<Transport>,
    zone_map: HashMap<String, Zone>,
}

impl Roon {
    pub async fn start() -> (Roon, Receiver<RoonEvent>) {
        let (tx, rx) = channel::<RoonEvent>(4);
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

    pub async fn get_image(&self, image_key: &str, args: Args) {
        let mut handler = self.handler.lock().await;

        if let Some(image) = handler.image.as_mut() {
            image.get_image(image_key, args).await;
        }
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
}

impl RoonHandler {
    fn new(event_tx: Sender<RoonEvent>) -> Self {
        Self {
            event_tx,
            browse: None,
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

    async fn handle_msg_event(&mut self, msg: Option<(Value, Parsed)>) {
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
                Parsed::Jpeg((image_key, image)) => {
                    self.event_tx
                        .send(RoonEvent::Image(vec![(image_key, image)]))
                        .await
                        .unwrap();
                }
                _ => (),
            }
        }
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
