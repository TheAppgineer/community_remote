#[derive(Clone, Debug)]
pub enum ZoneState {
    Playing,
    Loading,
    Paused,
    Stopped,
}

impl ZoneState {
    pub fn from(inner: roon_api::transport::State) -> ZoneState {
        match inner {
            roon_api::transport::State::Loading => ZoneState::Loading,
            roon_api::transport::State::Paused => ZoneState::Paused,
            roon_api::transport::State::Playing => ZoneState::Playing,
            roon_api::transport::State::Stopped => ZoneState::Stopped,
        }
    }
}

#[flutter_rust_bridge::frb(opaque)]
pub struct ZoneNowPlaying(roon_api::transport::NowPlaying);

impl ZoneNowPlaying {
    pub fn new(inner: roon_api::transport::NowPlaying) -> ZoneNowPlaying {
        Self(inner)
    }

    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn artist_image_key(&self) -> Option<Vec<String>> {
        self.0.artist_image_keys.as_ref().cloned()
    }

    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn image_key(&self) -> Option<String> {
        self.0.image_key.as_ref().cloned()
    }

    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn length(&self) -> Option<u32> {
        self.0.length
    }

    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn seek_position(&self) -> Option<i64> {
        self.0.seek_position
    }

    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn one_line(&self) -> String {
        let one_line = &self.0.one_line;

        one_line.line1.to_owned()
    }

    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn two_line(&self) -> Vec<String> {
        let two_line = &self.0.two_line;

        vec![two_line.line1.to_owned(), two_line.line2.to_owned()]
    }

    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn three_line(&self) -> Vec<String> {
        let three_line = &self.0.three_line;

        vec![
            three_line.line1.to_owned(),
            three_line.line2.to_owned(),
            three_line.line3.to_owned(),
        ]
    }
}

#[flutter_rust_bridge::frb(opaque)]
pub struct RoonZone(roon_api::transport::Zone);

impl RoonZone {
    pub fn new(inner: roon_api::transport::Zone) -> RoonZone {
        Self(inner)
    }

    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn display_name(&self) -> String {
        self.0.display_name.to_owned()
    }

    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn state(&self) -> ZoneState {
        ZoneState::from(self.0.state.to_owned())
    }

    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn now_playing(&self) -> Option<ZoneNowPlaying> {
        Some(ZoneNowPlaying::new(self.0.now_playing.to_owned()?))
    }
}
