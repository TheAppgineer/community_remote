use flutter_rust_bridge::DartFnFuture;
use once_cell::sync::Lazy;
use serde::{Deserialize, Serialize};
use tokio::sync::Mutex;

use crate::backend::roon::Roon;

use super::roon_browse_wrapper::BrowseItem;
use super::roon_transport_wrapper::{RoonZone, ZoneState};

static API: Lazy<Mutex<InternalState>> = Lazy::new(|| Mutex::new(InternalState::new()));

pub enum RoonEvent {
    CoreFound(String),
    CoreLost(String),
    ZonesChanged(Vec<ZoneSummary>),
    ZoneSelected(RoonZone),
    BrowseItems(BrowseItems),
    Image(ImageKeyValue),
    Settings(Settings),
}

pub struct BrowseItems {
    pub title: String,
    pub level: u32,
    pub offset: usize,
    pub total: usize,
    pub items: Vec<BrowseItem>,
}

pub struct ImageKeyValue {
    pub image_key: String,
    pub image: Vec<u8>,
}

pub struct ZoneSummary {
    pub zone_id: String,
    pub display_name: String,
    pub state: ZoneState,
    pub now_playing: Option<String>,
    pub image_key: Option<String>,
}

#[derive(Clone, Debug, Default, Deserialize, Serialize)]
enum ThemeEnum {
    Dark,
    #[default]
    Light,
    System,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[flutter_rust_bridge::frb(opaque)]
pub struct Settings {
    expand: bool,
    theme: ThemeEnum,
    view: i32,
    zone_id: Option<String>,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            expand: false,
            theme: Default::default(),
            view: 12,
            zone_id: Default::default(),
        }
    }
}

impl Settings {
    pub async fn set_expand(mut self, expand: bool) {
        self.expand = expand;
        let api = API.lock().await;

        if let Some(roon) = api.roon.as_ref() {
            roon.save(self).await;
        }
    }

    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn expand(&self) -> bool {
        self.expand
    }

    pub async fn set_view(mut self, view: i32) {
        self.view = view;
        let api = API.lock().await;

        if let Some(roon) = api.roon.as_ref() {
            roon.save(self).await;
        }
    }

    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn view(&self) -> i32 {
        self.view.to_owned()
    }
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
    let (roon, mut rx, settings) = Roon::start().await;
    let mut api = API.lock().await;

    cb(RoonEvent::Settings(settings)).await;

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

    if let Some(roon) = api.roon.as_ref() {
        roon.get_image(image_key, width, height).await;
    }
}

pub async fn browse(category: i32, session_id: i32) {
    let api = API.lock().await;

    if let Some(roon) = api.roon.as_ref() {
        roon.browse_category(category, session_id).await;
    }
}

pub async fn browse_next_page() {
    let api = API.lock().await;

    if let Some(roon) = api.roon.as_ref() {
        roon.browse_more().await;
    }
}

pub async fn browse_back(session_id: i32) {
    let api = API.lock().await;

    if let Some(roon) = api.roon.as_ref() {
        roon.browse_back(session_id).await;
    }
}

pub async fn select_browse_item(session_id: i32, item_key: Option<String>) {
    let api = API.lock().await;

    if let Some(roon) = api.roon.as_ref() {
        roon.select_browse_item(session_id, item_key).await;
    }
}
