#[flutter_rust_bridge::frb(opaque)]
pub struct BrowseItem(roon_api::browse::Item);

impl BrowseItem {
    pub fn new(inner: roon_api::browse::Item) -> BrowseItem {
        Self(inner)
    }

    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn title(&self) -> String {
        self.0.title.to_owned()
    }

    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn subtitle(&self) -> Option<String> {
        self.0.subtitle.as_ref().cloned()
    }

    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn image_key(&self) -> Option<String> {
        self.0.image_key.as_ref().cloned()
    }

    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn item_key(&self) -> Option<String> {
        self.0.item_key.as_ref().cloned()
    }
}
