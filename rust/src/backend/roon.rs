use roon_api::{
    browse::Browse, info, transport::Transport, CoreEvent, Info, Parsed, RoonApi, Services, Svc,
};
use serde_json::Value;
use std::collections::HashMap;
use tokio::sync::mpsc::{channel, Receiver, Sender};

const CONFIG_PATH: &str = "config.json";

pub enum RoonEvent {
    CoreFound(String),
    CoreLost(String),
}

pub struct Roon;

struct RoonHandler {
    event_tx: Sender<RoonEvent>,
    browse: Option<Browse>,
    transport: Option<Transport>,
}

impl Roon {
    pub async fn start() -> Receiver<RoonEvent> {
        let (tx, rx) = channel::<RoonEvent>(4);
        let info = info!("com.theappgineer", "Community Remote");
        let mut roon = RoonApi::new(info);

        let get_roon_state = Box::new(|| RoonApi::load_config(CONFIG_PATH, "roonstate"));
        let provided: HashMap<String, Svc> = HashMap::new();
        let services = Some(vec![
            Services::Browse(Browse::new()),
            Services::Transport(Transport::new()),
        ]);

        tokio::spawn(async move {
            if let Some((mut handlers, mut core_rx)) = roon
                .start_discovery(get_roon_state, provided, services)
                .await
            {
                handlers.spawn(async move {
                    let mut roon_handler = RoonHandler::new(tx);

                    loop {
                        if let Some((core_event, msg)) = core_rx.recv().await {
                            roon_handler.handle_core_event(core_event).await;
                            roon_handler.handle_msg_event(msg).await;
                        }
                    }
                });

                handlers.join_next().await;
            }
        });

        rx
    }
}

impl RoonHandler {
    fn new(event_tx: Sender<RoonEvent>) -> Self {
        Self {
            event_tx,
            browse: None,
            transport: None,
        }
    }

    async fn handle_core_event(&mut self, core_event: CoreEvent) -> Option<()> {
        match core_event {
            CoreEvent::Found(mut core) => {
                self.transport = core.get_transport().cloned();
                self.browse = core.get_browse().cloned();

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

    async fn handle_msg_event(&self, msg: Option<(Value, Parsed)>) {
        if let Some((raw, parsed)) = msg {
            match parsed {
                Parsed::RoonState => {
                    RoonApi::save_config(CONFIG_PATH, "roonstate", raw).unwrap();
                }
                Parsed::Zones(_) => (),
                Parsed::ZonesRemoved(_) => (),
                _ => (),
            }
        }
    }
}
