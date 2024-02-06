use flutter_rust_bridge::DartFnFuture;
use once_cell::sync::Lazy;
use roon_api::image::{Args, Scale, Scaling};
use tokio::sync::Mutex;

use crate::api::roon_transport_wrapper::RoonZone;
use crate::backend::roon::{Roon, ZoneSummary};

static API: Lazy<Mutex<InternalState>> = Lazy::new(|| Mutex::new(InternalState::new()));

pub enum RoonEvent {
    CoreFound(String),
    CoreLost(String),
    ZonesChanged(Vec<ZoneSummary>),
    ZoneSelected(RoonZone),
    Image(Vec<(String, Vec<u8>)>),
}

struct InternalState {
    roon: Option<Roon>,
}

impl InternalState {
    fn new() -> Self {
        Self { roon: None }
    }
}

#[flutter_rust_bridge::frb(init)]
pub async fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
    simple_logging::log_to_stderr(log::LevelFilter::Info);
}

pub async fn start_roon(cb: impl Fn(RoonEvent) -> DartFnFuture<()> + Send + 'static) {
    let (roon, mut rx) = Roon::start().await;
    let mut api = API.lock().await;

    api.roon = Some(roon);

    tokio::spawn(async move {
        loop {
            if let Some(event) = rx.recv().await {
                cb(event).await;
            }
        }
    });
}

pub async fn select_zone(zone_id: String) {
    let api = API.lock().await;

    if let Some(roon) = api.roon.as_ref() {
        roon.select_zone(&zone_id).await;
    }
}

pub async fn get_image(image_key: String, width: u32, height: u32) {
    let api = API.lock().await;
    let scaling = Some(Scaling::new(Scale::Fill, width, height));
    let args = Args::new(scaling, None);

    if let Some(roon) = api.roon.as_ref() {
        roon.get_image(&image_key, args).await;
    }
}
