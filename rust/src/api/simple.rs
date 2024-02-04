use flutter_rust_bridge::DartFnFuture;
use once_cell::sync::Lazy;
use roon_api::image::{Args, Scale, Scaling};
use tokio::sync::Mutex;

use crate::backend::roon::{Roon, RoonEvent};

static API: Lazy<Mutex<InternalState>> = Lazy::new(|| Mutex::new(InternalState::new()));

struct InternalState {
    counter: u32,
    roon: Option<Roon>,
}

impl InternalState {
    fn new() -> Self {
        Self {
            counter: 0,
            roon: None,
        }
    }
}

pub async fn inc_counter() -> u32 {
    let mut api = API.lock().await;

    api.counter += 1;

    api.counter
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
        roon.select_zone(&zone_id);
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
