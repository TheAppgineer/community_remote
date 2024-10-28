use roon_api::browse::Item as BrowseItem;
use roon_api::browse::ItemHint as BrowseItemHint;
use roon_api::{
    browse::{Browse, BrowseOpts, LoadOpts},
    image::{Args, Image, Scale, Scaling},
    info, settings,
    status::{self, Status},
    transport::{
        volume::{ChangeMode, Mute},
        Control, State, Transport,
    },
    Info, RoonApi, Services, Svc,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::{
    collections::HashMap,
    net::{IpAddr, Ipv4Addr},
    str::FromStr,
    sync::Arc,
};
use tokio::{
    sync::{
        mpsc::{channel, Receiver},
        Mutex,
    },
    time::{self, sleep, Duration},
};

use crate::api::simple::RoonEvent;
use crate::backend::{
    roon_access::{RoonAccess, RoonAccessData},
    roon_handler::{RoonHandler, BROWSE_PAGE_SIZE, COUNTRY_CODE},
};

const PLAY_NOW: &str = "Play Now";
const ADD_NEXT: &str = "Add Next";
const QUEUE: &str = "Queue";

pub struct Roon {
    config_path: Arc<String>,
    support_path: String,
    handler: Arc<Mutex<RoonHandler>>,
    server: Arc<Mutex<ServerProps>>,
}

#[derive(Clone, Default, Deserialize, Serialize)]
struct ServerProps {
    ip: Option<String>,
    port: Option<String>,
}

impl Roon {
    pub async fn start(support_path: String) -> (Roon, Receiver<RoonEvent>, String) {
        let (tx, rx) = channel::<RoonEvent>(10);
        let info = info!("com.theappgineer", "Community Remote");
        let mut roon = RoonApi::new(info);
        let wikipedia = format!("{}/wikipedia.json", support_path);
        let cache = RoonApi::load_config(&wikipedia, COUNTRY_CODE);
        let config_path = Arc::new(support_path.clone() + "/config.json");
        let value = RoonApi::load_config(&config_path, "settings");
        let server = RoonApi::load_config(&config_path, "server");
        let server = Arc::new(Mutex::new(
            serde_json::from_value::<ServerProps>(server).unwrap_or_default(),
        ));
        let fallback = if COUNTRY_CODE != "en" {
            RoonApi::load_config(&wikipedia, "en")
        } else {
            Value::Null
        };
        let handler = RoonHandler::new(tx, config_path.clone(), COUNTRY_CODE, cache, fallback);
        let handler = Arc::new(Mutex::new(handler));

        log::info!("Loading config from: {config_path}");

        let handler_clone = handler.clone();
        let config_path_clone = config_path.clone();
        let server_clone = server.clone();
        tokio::spawn(async move {
            loop {
                let (settings_svc, settings, access) =
                    RoonAccess::new(config_path_clone.clone(), &roon);
                let (status_svc, status) = Status::new(&roon);
                let services = Some(vec![
                    Services::Browse(Browse::new()),
                    Services::Transport(Transport::new()),
                    Services::Image(Image::new()),
                    Services::Settings(settings),
                    Services::Status(status),
                ]);
                let provided: HashMap<String, Svc> = HashMap::from([
                    (settings::SVCNAME.to_owned(), settings_svc),
                    (status::SVCNAME.to_owned(), status_svc),
                ]);
                let config_path = config_path_clone.clone();
                let get_roon_state = Box::new(move || RoonApi::load_roon_state(&config_path));
                let timeout = Duration::from_secs(20);
                let connection = {
                    let server = server_clone.lock().await;

                    if let Some(ip) = server.ip.as_deref() {
                        let ip_addr = IpAddr::V4(Ipv4Addr::from_str(ip).unwrap());
                        let port = server.port.as_deref().unwrap_or("9330");

                        log::info!("Connecting to: {ip}:{port}...");
                        time::timeout(
                            timeout,
                            roon.ws_connect(get_roon_state, provided, services, &ip_addr, port),
                        )
                        .await
                    } else {
                        log::info!("Starting Server discovery...");
                        time::timeout(
                            timeout,
                            roon.start_discovery(get_roon_state, provided, services),
                        )
                        .await
                    }
                };

                if let Ok(Some((mut handlers, mut core_rx))) = connection {
                    let roon_handler = handler_clone.clone();

                    {
                        let mut handler = roon_handler.lock().await;
                        handler.zone_id = None;
                        handler.set_access(access);
                    }

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
            support_path,
            handler,
            server,
        };

        (roon, rx, value.to_string())
    }

    pub async fn set_server_properties(&mut self, ip: String, port: Option<String>) {
        let server_props = ServerProps { ip: Some(ip), port };

        *(self.server.lock().await) = server_props.clone();

        let value = server_props
            .serialize(serde_json::value::Serializer)
            .unwrap();

        if let Err(err) = RoonApi::save_config(&self.config_path, "server", value) {
            log::warn!("Failed to save server config: {err}");
        }
    }

    pub fn get_server_properties(&self) -> Option<(String, String)> {
        let value = RoonApi::load_config(&self.config_path, "server");
        let server_props = serde_json::from_value::<ServerProps>(value).ok()?;

        Some((server_props.ip?, server_props.port?))
    }

    pub async fn set_status_message(&self, message: String) {
        let handler = self.handler.lock().await;

        handler.set_status_message(message).await;
    }

    pub async fn get_thumbnail(&self, image_key: String) -> Option<()> {
        let handler = self.handler.lock().await;
        let scaling = Some(Scaling::new(Scale::Fill, 100, 100));
        let args = Args::new(scaling, None);

        handler.image.as_ref()?.get_image(&image_key, args).await;

        Some(())
    }

    pub async fn get_image(&self, image_key: String) -> Option<()> {
        let handler = self.handler.lock().await;
        let scaling = Some(Scaling::new(Scale::Fill, 1000, 1000));
        let args = Args::new(scaling, None);

        handler.image.as_ref()?.get_image(&image_key, args).await;

        Some(())
    }

    pub async fn select_zone(&self, zone_id: &str) -> Option<()> {
        let mut handler = self.handler.lock().await;

        let result = handler.select_zone(zone_id).await;

        if let Some(value) = handler.mediawiki.get_changed_cache() {
            let path = format!("{}/wikipedia.json", self.support_path);

            RoonApi::save_config(&path, COUNTRY_CODE, value).unwrap();
        }

        result
    }

    pub async fn transfer_from_zone(&self, zone_id: &str) -> Option<()> {
        let handler = self.handler.lock().await;

        handler
            .transport
            .as_ref()?
            .transfer_zone(zone_id, handler.zone_id.as_deref()?)
            .await;

        Some(())
    }

    pub async fn browse_category(&self, category: i32, input: Option<String>) -> Option<()> {
        let access = RoonApi::load_config(&self.config_path, "access");

        serde_json::from_value::<RoonAccessData>(access).ok()?;

        let mut handler = self.handler.lock().await;
        let category_paths = HashMap::from([
            (0, vec!["Search", "Library"]),
            (1, vec!["Artists", "Library"]),
            (2, vec!["Albums", "Library"]),
            (3, vec!["Tracks", "Library"]),
            (4, vec!["Genres"]),
            (5, vec!["Composers", "Library"]),
            (6, vec!["Tags", "Library"]),
            (7, vec!["My Live Radio"]),
            (8, vec!["Playlists"]),
            (9, vec!["KKBOX"]),
            (10, vec!["Qobuz"]),
            (11, vec!["TIDAL"]),
            (12, vec!["Settings"]),
        ]);
        let multi_session_key = handler.get_multi_session_key();

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

        handler.browse.as_mut()?.browse_clear();
        handler.browse.as_mut()?.browse(opts).await;
        handler.browse_category = Some(category);
        handler.browse_input = input;

        Some(())
    }

    pub async fn select_browse_item(&self, item: BrowseItem) -> Option<()> {
        let item_key = item.item_key.as_deref()?;
        let multi_session_key = self.handler.lock().await.get_multi_session_key();

        if item_key.contains("random") {
            self.handle_random_item(multi_session_key, &item).await;
        } else {
            self.handler.lock().await.select_browse_item(item).await;
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

    pub async fn browse_back(&self) -> Option<()> {
        let mut handler = self.handler.lock().await;

        if handler.browse_level > 0 {
            let multi_session_key = handler.get_multi_session_key();
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

    pub async fn search_artist(&self, artist: String) -> Option<()> {
        let path = vec![
            artist.to_owned(),
            "Artists".to_owned(),
            "Search".to_owned(),
            "Library".to_owned(),
        ];
        let mut handler = self.handler.lock().await;
        let multi_session_key = handler.get_multi_session_key();

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

        handler.pause_whitelisted_outputs().await;

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

    pub async fn mute_zone(&self) {
        let mut handler = self.handler.lock().await;

        handler.set_mute_list();
        handler.handle_mute_list().await;
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

    pub async fn get_about(&mut self) -> Option<()> {
        let mut handler = self.handler.lock().await;
        let result = handler.get_about().await;

        if let Some(value) = handler.mediawiki.get_changed_cache() {
            let path = format!("{}/wikipedia.json", self.support_path);

            RoonApi::save_config(&path, COUNTRY_CODE, value).unwrap();
        }

        result
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
