use flutter_rust_bridge::DartFnFuture;
use once_cell::sync::Lazy;
use std::sync::Mutex;

use crate::backend::roon::{Roon, RoonEvent};

static API: Lazy<Mutex<State>> = Lazy::new(|| Mutex::new(State::new()));

#[flutter_rust_bridge::frb(opaque)]
struct State {
    counter: u32,
}

impl State {
    fn new() -> Self {
        Self {
            counter: 0,
        }
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn inc_counter() {
    let mut api = API.lock().unwrap();

    api.counter += 1;
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_counter() -> u32 {
    let api = API.lock().unwrap();

    api.counter
}

#[flutter_rust_bridge::frb(init)]
pub async fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
    simple_logging::log_to_stderr(log::LevelFilter::Info);
}

pub async fn start_roon(cb: impl Fn(RoonEvent) -> DartFnFuture<()> + Send + 'static) {
    let mut rx = Roon::new().await;

    tokio::spawn(async move {
        loop {
            match rx.recv().await {
                Some(event) => cb(event).await,
                None => (),
            }
        }
    });
}
