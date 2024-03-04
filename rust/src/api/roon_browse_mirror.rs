pub use roon_api::browse::{BrowseItem, BrowseItemHint, BrowseList, BrowseListHint, InputPrompt};

#[flutter_rust_bridge::frb(mirror(BrowseListHint))]
pub enum _BrowseListHint {
    None,
    ActionList,
}

#[flutter_rust_bridge::frb(mirror(BrowseList))]
pub struct _BrowseList {
    pub title: String,
    pub count: usize,
    pub level: u32,
    pub subtitle: Option<String>,
    pub image_key: Option<String>,
    pub display_offset: Option<usize>,
    pub hint: Option<BrowseListHint>,
}

#[flutter_rust_bridge::frb(mirror(BrowseItemHint))]
pub enum _BrowseItemHint {
    None,
    Action,
    ActionList,
    List,
    Header,
}

#[flutter_rust_bridge::frb(mirror(InputPrompt))]
pub struct _InputPrompt {
    pub prompt: String,
    pub action: String,
    pub value: Option<String>,
    pub is_password: Option<bool>,
}

#[flutter_rust_bridge::frb(mirror(BrowseItem))]
pub struct _BrowseItem {
    pub title: String,
    pub subtitle: Option<String>,
    pub image_key: Option<String>,
    pub item_key: Option<String>,
    pub hint: Option<BrowseItemHint>,
    pub input_prompt: Option<InputPrompt>,
}
