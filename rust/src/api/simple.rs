use std::collections::HashMap;
use std::fs::File;

use flutter_rust_bridge::DartFnFuture;
use once_cell::sync::Lazy;
use roon_api::browse::Item as BrowseItem;
use roon_api::browse::List as BrowseList;
use roon_api::transport::State as PlayState;
use roon_api::transport::ZoneSeek;
use roon_api::transport::{
    volume::{ChangeMode, Mute},
    Control, QueueItem, Zone,
};
use simplelog::{
    format_description, ColorChoice, ConfigBuilder, TermLogger, TerminalMode, WriteLogger,
};
use time::UtcOffset;
use tokio::sync::Mutex;

use crate::backend::roon::Roon;

static API: Lazy<Mutex<InternalState>> = Lazy::new(|| Mutex::new(InternalState::new()));

pub enum RoonEvent {
    CoreDiscovered(String, Option<String>),
    CoreRegistered(String, String),
    CorePermitted(String, bool),
    CoreLost(String),
    ZonesChanged(Vec<ZoneSummary>),
    ZoneChanged(Option<Zone>),
    ZoneSeek(ZoneSeek),
    OutputsChanged(HashMap<String, String>),
    BrowseItems(BrowseItems),
    BrowseActions(Vec<BrowseItem>),
    BrowseReset,
    Profile(String),
    QueueItems(Vec<QueueItem>),
    PauseOnTrackEnd(bool),
    Image(ImageKeyValue),
    SettingsSaved,
    Services(Vec<String>),
    WikiExtract(String),
    About(BrowseItems),
}

pub struct BrowseItems {
    pub list: BrowseList,
    pub offset: u32,
    pub items: Vec<BrowseItem>,
}

pub struct ImageKeyValue {
    pub image_key: String,
    pub image: Vec<u8>,
}

pub struct ZoneSummary {
    pub zone_id: String,
    pub output_ids: Vec<String>,
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
    flutter_rust_bridge::setup_default_user_utils();
}

pub async fn start_roon(
    support_path: String,
    cb: impl Fn(RoonEvent) -> DartFnFuture<()> + Send + 'static,
) -> String {
    init_logger(&support_path, log::LevelFilter::Info);

    let (roon, mut rx, settings) = Roon::start(support_path).await;
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

pub async fn set_server_properties(ip: String, port: Option<String>) {
    let mut api = API.lock().await;

    if let Some(roon) = api.roon.as_mut() {
        roon.set_server_properties(ip, port).await;
    }
}

pub async fn get_server_properties() -> Option<(String, String)> {
    let mut api = API.lock().await;

    if let Some(roon) = api.roon.as_mut() {
        roon.get_server_properties()
    } else {
        None
    }
}

pub async fn set_status_message(message: String) {
    let mut api = API.lock().await;

    if let Some(roon) = api.roon.as_mut() {
        roon.set_status_message(message).await;
    }
}

fn init_logger(support_path: &str, log_level: log::LevelFilter) {
    let log_path = format!("{support_path}/messages.log");
    let time_format = format_description!("[hour]:[minute]:[second].[subsecond]");
    let seconds = chrono::Local::now().offset().local_minus_utc();
    let utc_offset = UtcOffset::from_whole_seconds(seconds).unwrap_or(UtcOffset::UTC);
    let config = ConfigBuilder::new()
        .set_time_format_custom(time_format)
        .set_time_offset(utc_offset)
        .build();

    let _ = match File::create(log_path) {
        Ok(log_path) => WriteLogger::init(log_level, config, log_path),
        Err(_) => TermLogger::init(log_level, config, TerminalMode::Stdout, ColorChoice::Never),
    };

    if utc_offset == UtcOffset::UTC {
        log::warn!("Timestamps are UTC");
    } else {
        log::info!("Timestamps are local time");
    }
}

pub async fn select_zone(zone_id: String) {
    let api = API.lock().await;

    if let Some(roon) = api.roon.as_ref() {
        roon.select_zone(&zone_id).await;
    }
}

pub async fn transfer_from_zone(zone_id: String) {
    let api = API.lock().await;

    if let Some(roon) = api.roon.as_ref() {
        roon.transfer_from_zone(&zone_id).await;
    }
}

pub async fn get_thumbnail(image_key: String) {
    let api = API.lock().await;

    if let Some(roon) = api.roon.as_ref() {
        roon.get_thumbnail(image_key).await;
    }
}

pub async fn get_image(image_key: String) {
    let api = API.lock().await;

    if let Some(roon) = api.roon.as_ref() {
        roon.get_image(image_key).await;
    }
}

pub async fn browse(category: i32) {
    let api = API.lock().await;

    if let Some(roon) = api.roon.as_ref() {
        roon.browse_category(category, None).await;
    }
}

pub async fn browse_with_input(category: i32, input: Option<String>) {
    let api = API.lock().await;

    if let Some(roon) = api.roon.as_ref() {
        roon.browse_category(category, input).await;
    }
}

pub async fn browse_next_page() {
    let api = API.lock().await;

    if let Some(roon) = api.roon.as_ref() {
        roon.browse_more().await;
    }
}

pub async fn browse_back() {
    let api = API.lock().await;

    if let Some(roon) = api.roon.as_ref() {
        roon.browse_back().await;
    }
}

pub async fn search_artist(artist: String) {
    let api = API.lock().await;

    if let Some(roon) = api.roon.as_ref() {
        roon.search_artist(artist).await;
    }
}

pub async fn select_browse_item(item: BrowseItem) {
    let api = API.lock().await;

    if let Some(roon) = api.roon.as_ref() {
        roon.select_browse_item(item).await;
    }
}
pub async fn select_queue_item(queue_item_id: u32) {
    let api = API.lock().await;

    if let Some(roon) = api.roon.as_ref() {
        roon.select_queue_item(queue_item_id).await;
    }
}

pub async fn pause_after_queue_items(queue_item_ids: Vec<u32>) {
    let api = API.lock().await;

    if let Some(roon) = api.roon.as_ref() {
        roon.pause_after_queue_items(queue_item_ids).await;
    }
}

pub async fn save_settings(settings: String) {
    let api = API.lock().await;

    if let Some(roon) = api.roon.as_ref() {
        roon.save(settings).await;
    }
}

pub async fn control(control: Control) {
    let api = API.lock().await;

    if let Some(roon) = api.roon.as_ref() {
        roon.control(&control).await;
    }
}

pub async fn control_by_zone_id(zone_id: String, control: Control) {
    let api = API.lock().await;

    if let Some(roon) = api.roon.as_ref() {
        roon.control_by_zone_id(&zone_id, &control).await;
    }
}

pub async fn pause_all() {
    let api = API.lock().await;

    if let Some(roon) = api.roon.as_ref() {
        roon.pause_all().await;
    }
}

pub async fn pause_on_track_end() {
    let api = API.lock().await;

    if let Some(roon) = api.roon.as_ref() {
        roon.pause_on_track_end().await;
    }
}

pub async fn mute(output_id: String, how: Mute) {
    let api = API.lock().await;

    if let Some(roon) = api.roon.as_ref() {
        roon.mute(&output_id, &how).await;
    }
}

pub async fn mute_all() {
    let api = API.lock().await;

    if let Some(roon) = api.roon.as_ref() {
        roon.mute_all().await;
    }
}

pub async fn mute_zone() {
    let api = API.lock().await;

    if let Some(roon) = api.roon.as_ref() {
        roon.mute_zone().await;
    }
}

pub async fn change_volume(output_id: String, how: ChangeMode, value: i32) {
    let api = API.lock().await;

    if let Some(roon) = api.roon.as_ref() {
        roon.change_volume(&output_id, &how, value).await;
    }
}

pub async fn change_zone_volume(how: &ChangeMode, value: i32) {
    let api = API.lock().await;

    if let Some(roon) = api.roon.as_ref() {
        roon.change_zone_volume(&how, value).await;
    }
}

pub async fn standby(output_id: String) {
    let api = API.lock().await;

    if let Some(roon) = api.roon.as_ref() {
        roon.standby(&output_id).await;
    }
}

pub async fn group_outputs(output_ids: Vec<String>) {
    let api = API.lock().await;

    if let Some(roon) = api.roon.as_ref() {
        roon.group_outputs(output_ids).await;
    }
}

pub async fn get_about() {
    let mut api = API.lock().await;

    if let Some(roon) = api.roon.as_mut() {
        roon.get_about().await;
    }
}
