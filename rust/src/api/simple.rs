use flutter_rust_bridge::DartFnFuture;
use once_cell::sync::Lazy;
use roon_api::browse::Item as BrowseItem;
use roon_api::browse::List as BrowseList;
use roon_api::transport::State as PlayState;
use roon_api::transport::Zone;
use tokio::sync::Mutex;

use crate::backend::roon::Roon;

static API: Lazy<Mutex<InternalState>> = Lazy::new(|| Mutex::new(InternalState::new()));

pub enum RoonEvent {
    CoreFound(String),
    CoreLost(String),
    ZonesChanged(Vec<ZoneSummary>),
    ZoneChanged(Zone),
    BrowseItems(BrowseItems),
    BrowseActions(Vec<BrowseItem>),
    Image(ImageKeyValue),
    SettingsSaved,
}

pub struct BrowseItems {
    pub list: BrowseList,
    pub offset: usize,
    pub items: Vec<BrowseItem>,
}

pub struct ImageKeyValue {
    pub image_key: String,
    pub image: Vec<u8>,
}

pub struct ZoneSummary {
    pub zone_id: String,
    pub display_name: String,
    pub state: PlayState,
    pub now_playing: Option<String>,
    pub image_key: Option<String>,
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

pub async fn start_roon(cb: impl Fn(RoonEvent) -> DartFnFuture<()> + Send + 'static) -> String {
    let (roon, mut rx, settings) = Roon::start().await;
    let mut api = API.lock().await;

    api.roon = Some(roon);

    tokio::spawn(async move {
        loop {
            if let Some(event) = rx.recv().await {
                cb(event).await;
            }
        }
    });

    settings
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

pub async fn select_browse_item(session_id: i32, item: BrowseItem) {
    let api = API.lock().await;

    if let Some(roon) = api.roon.as_ref() {
        roon.select_browse_item(session_id, item).await;
    }
}

pub async fn save_settings(settings: String) {
    let api = API.lock().await;

    if let Some(roon) = api.roon.as_ref() {
        roon.save(settings).await;
    }
}
