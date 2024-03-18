pub use roon_api::transport::Settings as ZoneSettings;
pub use roon_api::transport::State as PlayState;
pub use roon_api::transport::{
    volume::{Scale, Volume},
    Control, NowPlaying, OneLine, Output, QueueItem, Repeat, SourceControls, Status, ThreeLine,
    TwoLine, Zone, ZoneSeek,
};

#[flutter_rust_bridge::frb(mirror(Control))]
pub enum _Control {
    Play,
    Pause,
    PlayPause,
    Stop,
    Previous,
    Next,
}

#[flutter_rust_bridge::frb(mirror(Scale))]
pub enum _Scale {
    Number,
    Decibel,
    Incremental,
}

#[flutter_rust_bridge::frb(mirror(PlayState))]
pub enum _PlayState {
    Playing,
    Paused,
    Loading,
    Stopped,
}

#[flutter_rust_bridge::frb(mirror(Repeat))]
pub enum _Repeat {
    Off,
    All,
    One,
}

#[flutter_rust_bridge::frb(mirror(Status))]
pub enum _Status {
    Selected,
    Deselected,
    Standby,
    Indeterminate,
}

#[flutter_rust_bridge::frb(mirror(NowPlaying))]
pub struct _NowPlaying {
    pub artist_image_keys: Option<Vec<String>>,
    pub image_key: Option<String>,
    pub length: Option<u32>,
    pub seek_position: Option<i64>,
    pub one_line: OneLine,
    pub two_line: TwoLine,
    pub three_line: ThreeLine,
}

#[flutter_rust_bridge::frb(mirror(QueueItem))]
pub struct _QueueItem {
    pub image_key: Option<String>,
    pub length: u32,
    pub queue_item_id: u32,
    pub one_line: OneLine,
    pub two_line: TwoLine,
    pub three_line: ThreeLine,
}

#[flutter_rust_bridge::frb(mirror(OneLine))]
pub struct _OneLine {
    pub line1: String,
}

#[flutter_rust_bridge::frb(mirror(TwoLine))]
pub struct _TwoLine {
    pub line1: String,
    pub line2: String,
}

#[flutter_rust_bridge::frb(mirror(ThreeLine))]
pub struct _ThreeLine {
    pub line1: String,
    pub line2: String,
    pub line3: String,
}

#[flutter_rust_bridge::frb(mirror(Output))]
pub struct _Output {
    pub output_id: String,
    pub zone_id: String,
    pub can_group_with_output_ids: Vec<String>,
    pub display_name: String,
    pub volume: Option<Volume>,
    pub source_controls: Option<Vec<SourceControls>>,
}

#[flutter_rust_bridge::frb(mirror(ZoneSettings))]
pub struct _ZoneSettings {
    pub repeat: Repeat,
    pub shuffle: bool,
    pub auto_radio: bool,
}

#[flutter_rust_bridge::frb(mirror(SourceControls))]
pub struct _SourceControls {
    pub control_key: String,
    pub display_name: String,
    pub supports_standby: bool,
    pub status: Status,
}

#[flutter_rust_bridge::frb(mirror(Volume))]
pub struct _Volume {
    pub scale: Scale,
    pub min: Option<f32>,
    pub max: Option<f32>,
    pub value: Option<f32>,
    pub step: Option<f32>,
    pub is_muted: Option<bool>,
    pub hard_limit_min: f32,
    pub hard_limit_max: f32,
    pub soft_limit: f32,
}

#[flutter_rust_bridge::frb(mirror(Zone))]
pub struct _Zone {
    pub zone_id: String,
    pub display_name: String,
    pub outputs: Vec<Output>,
    pub state: PlayState,
    pub is_next_allowed: bool,
    pub is_previous_allowed: bool,
    pub is_pause_allowed: bool,
    pub is_play_allowed: bool,
    pub is_seek_allowed: bool,
    pub queue_items_remaining: i64,
    pub queue_time_remaining: i64,
    pub now_playing: Option<NowPlaying>,
    pub settings: ZoneSettings,
}

#[flutter_rust_bridge::frb(mirror(ZoneSeek))]
pub struct _ZoneSeek {
    pub zone_id: String,
    pub queue_time_remaining: i64,
    pub seek_position: Option<i64>,
}
