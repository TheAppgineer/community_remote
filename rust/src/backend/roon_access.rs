use roon_api::{
    settings::{BoxedSerTrait, Dropdown, Layout, SerTrait, Settings, Widget},
    RoonApi, Svc,
};
use serde::{Deserialize, Serialize};
use std::sync::{Arc, Mutex};

pub struct RoonAccess {
    profiles: Option<Vec<String>>,
    data: Option<RoonAccessData>,
}

#[derive(Clone, Debug, Default, Deserialize, Serialize)]
pub struct RoonAccessData {
    pub profile: String,
}

#[derive(Deserialize, Serialize)]
struct ProfileEntry {
    title: String,
    value: String,
}

#[typetag::serde]
impl SerTrait for ProfileEntry {}

impl ProfileEntry {
    fn from(title: String, value: String) -> BoxedSerTrait {
        Box::new(Self { title, value }) as BoxedSerTrait
    }
}

impl RoonAccess {
    pub fn new(
        config_path: Arc<String>,
        roon: &RoonApi,
    ) -> (Svc, Settings, Arc<Mutex<RoonAccess>>) {
        let access = Arc::new(Mutex::new(RoonAccess {
            profiles: None,
            data: None,
        }));
        let access_clone = access.clone();
        let get_layout = move |settings: Option<RoonAccessData>| -> Layout<RoonAccessData> {
            let settings = match settings {
                Some(settings) => settings,
                None => {
                    let value = RoonApi::load_config(&config_path, "access");

                    serde_json::from_value(value).unwrap_or_default()
                }
            };

            Self::make_layout(settings, access_clone.clone())
        };
        let (svc, settings) = Settings::new(&roon, Box::new(get_layout));

        (svc, settings, access)
    }

    pub fn set_profiles(&mut self, profiles: Vec<String>) {
        self.profiles = Some(profiles);
    }

    pub fn set_data(&mut self, data: RoonAccessData) {
        self.data = Some(data);
    }

    pub fn has_data(&self) -> bool {
        self.data.is_some()
    }

    pub fn has_profile_access(&self) -> bool {
        if let Some(data) = &self.data {
            data.profile.is_empty()
        } else {
            false
        }
    }

    fn make_layout(
        settings: RoonAccessData,
        access: Arc<Mutex<RoonAccess>>,
    ) -> Layout<RoonAccessData> {
        let has_error = false;
        let access = access.lock().unwrap();
        let mut values = vec![ProfileEntry::from(
            "User Selected".to_string(),
            "".to_string(),
        )];

        if let Some(profiles) = access.profiles.as_ref() {
            for profile in profiles {
                values.push(ProfileEntry::from(profile.to_owned(), profile.to_owned()));
            }
        }

        let dropdown = Dropdown {
            title: "Profile",
            subtitle: None,
            values,
            setting: "profile",
        };
        let widgets = vec![Widget::Dropdown(dropdown)];

        Layout {
            settings,
            widgets,
            has_error,
        }
    }
}
