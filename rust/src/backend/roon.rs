use roon_api::{info, transport::Transport, CoreEvent, Info, Parsed, RoonApi, Services, Svc};
use serde_json::Value;
use std::collections::HashMap;
use tokio::sync::mpsc::{channel, Receiver, Sender};

const CONFIG_PATH: &str = "config.json";

pub enum RoonEvent {
    CoreFound(String),
    CoreLost(String),
}

pub struct Roon;

impl Roon {
    pub async fn new() -> Receiver<RoonEvent> {
        let (tx, rx) = channel::<RoonEvent>(4);
        let info = info!("com.theappgineer", "Community Remote");
        let mut roon = RoonApi::new(info);

        let get_roon_state = Box::new(|| {
            RoonApi::load_config(CONFIG_PATH, "roonstate")
        });
        let provided: HashMap<String, Svc> = HashMap::new();
        let services = Some(vec![Services::Transport(Transport::new())]);

        tokio::spawn(async move {
            if let Some((mut handlers, mut core_rx)) = roon.start_discovery(
                get_roon_state,
                provided,
                services,
            ).await {
                handlers.spawn(async move {
                    loop {
                        match core_rx.recv().await {
                            Some((core_event, msg)) => {
                                Roon::handle_core_event(core_event, &tx).await;
                                Roon::handle_msg_event(msg);
                            }
                            None => (),
                        }
                    }
                });

                handlers.join_next().await;
            }
        });

        rx
    }

    async fn handle_core_event(core_event: CoreEvent, tx: &Sender<RoonEvent>) {
        match core_event {
            CoreEvent::Found(core) => {
                tx.send(RoonEvent::CoreFound(core.display_name)).await.unwrap();
            }
            CoreEvent::Lost(core) => {
                tx.send(RoonEvent::CoreLost(core.display_name)).await.unwrap();
            }
            _ => (),
        }
    }

    fn handle_msg_event(msg: Option<(Value, Parsed)>) {
        if let Some((raw, parsed)) = msg {
            match parsed {
                Parsed::RoonState => {
                    RoonApi::save_config(CONFIG_PATH, "roonstate", raw).unwrap();
                }
                _ => (),
            }
        }
    }
}
