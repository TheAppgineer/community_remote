use once_cell::sync::Lazy;
use std::sync::Mutex;

static API: Lazy<Mutex<State>> = Lazy::new(|| Mutex::new(State::new()));

#[derive(Default)]
#[flutter_rust_bridge::frb(opaque)]
struct State {
    counter: u32,
}

impl State {
    fn new() -> Self {
        Self::default()
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
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}
