use roon_api::{
    settings::{BoxedSerTrait, Dropdown, Group, Layout, SerTrait, Settings, Widget},
    RoonApi, Svc,
};
use serde::{Deserialize, Serialize};
use std::sync::{Arc, Mutex};

pub struct RoonAccess {
    profiles: Option<Vec<String>>,
    zones: Option<Vec<(String, String)>>,
    data: Option<RoonAccessData>,
}

#[derive(Clone, Debug, Default, Deserialize, Serialize)]
pub struct RoonAccessData {
    pub profile: String,
    pub zone_whitelist: Option<Vec<String>>,
    whitelist_remove: Option<String>,
    whitelist_add: Option<String>,
}

#[derive(Deserialize, Serialize)]
struct DropdownEntry {
    title: String,
    value: String,
}

#[typetag::serde]
impl SerTrait for DropdownEntry {}

impl DropdownEntry {
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
            zones: None,
            data: None,
        }));
        let access_clone = access.clone();
        let get_layout = move |settings: Option<RoonAccessData>| -> Layout<RoonAccessData> {
            fn update_whitelist(
                mut settings: RoonAccessData,
                zones: Option<&[(String, String)]>,
            ) -> RoonAccessData {
                let remove = settings.whitelist_remove.take();
                let add = settings.whitelist_add.take();
                let mut drop_whitelist = false;

                if (remove.is_some() || add.is_some()) && settings.zone_whitelist.is_none() {
                    if let Some(zones) = zones {
                        let whitelist = zones
                            .iter()
                            .map(|(_, id)| id.to_owned())
                            .collect::<Vec<_>>();

                        settings.zone_whitelist = Some(whitelist);
                    }
                }

                if let Some(whitelist) = settings.zone_whitelist.as_mut() {
                    if let Some(remove) = remove.as_ref() {
                        if let Some(index) = whitelist.iter().position(|id| id == remove) {
                            whitelist.remove(index);
                            drop_whitelist = whitelist.is_empty();
                        }
                    }

                    if let Some(add) = add {
                        if !whitelist.contains(&add) {
                            whitelist.push(add);
                        }
                    }
                }

                if drop_whitelist {
                    settings.zone_whitelist = None;
                }

                settings
            }

            let mut access = access_clone.lock().unwrap();
            let settings = match settings {
                Some(settings) => update_whitelist(settings, access.zones.as_deref()),
                None => {
                    let value = RoonApi::load_config(&config_path, "access");

                    serde_json::from_value(value).unwrap_or_default()
                }
            };

            Self::make_layout(settings, &mut access)
        };
        let (svc, settings) = Settings::new(&roon, Box::new(get_layout));

        (svc, settings, access)
    }

    pub fn set_profiles(&mut self, profiles: Vec<String>) {
        self.profiles = Some(profiles);
    }

    pub fn set_zones(&mut self, zones: &[(String, String)]) {
        self.zones = Some(Vec::from(zones));
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

    pub fn get_profile(&self) -> Option<String> {
        match self.data.as_ref() {
            Some(data) if !data.profile.is_empty() => Some(data.profile.to_owned()),
            _ => None,
        }
    }

    pub fn get_zone_ids(&self) -> Option<Vec<String>> {
        let ids = self
            .data
            .as_ref()?
            .zone_whitelist
            .as_ref()?
            .iter()
            .map(|id| id.to_owned())
            .collect();

        Some(ids)
    }

    fn make_layout(settings: RoonAccessData, access: &mut RoonAccess) -> Layout<RoonAccessData> {
        let has_error = false;
        let mut remove_values = Vec::new();
        let mut add_values = Vec::new();
        let mut profile_values = vec![DropdownEntry::from(
            "Selectable".to_string(),
            "".to_string(),
        )];
        let mut zone_whitelist = String::new();

        if let Some(profiles) = access.profiles.as_ref() {
            for profile in profiles {
                profile_values.push(DropdownEntry::from(profile.to_owned(), profile.to_owned()));
            }
        }

        let mut widgets = vec![Widget::Dropdown(Dropdown {
            title: "Profile",
            subtitle: Some("Allow profile selection or assign profile".to_owned()),
            values: profile_values,
            setting: "profile",
        })];

        if let Some(zones) = access.zones.as_ref() {
            let (group_title, remove_title, remove_subtitle) =
                if let Some(whitelist) = settings.zone_whitelist.as_ref() {
                    for (name, id) in zones {
                        if whitelist.contains(id) {
                            remove_values.push(DropdownEntry::from(name.to_owned(), id.to_owned()));
                            zone_whitelist.push_str(name);
                            zone_whitelist.push('\n');
                        } else {
                            add_values.push(DropdownEntry::from(name.to_owned(), id.to_owned()));
                        }
                    }

                    (
                        "Whitelisted zones:",
                        "Remove from whitelist",
                        Some("Remove all to allow all zones".to_owned()),
                    )
                } else {
                    for (name, id) in zones {
                        remove_values.push(DropdownEntry::from(name.to_owned(), id.to_owned()));
                        zone_whitelist.push_str(name);
                        zone_whitelist.push('\n');
                    }

                    ("All zones allowed", "Remove from zone list", None)
                };

            let mut items = Vec::new();

            if !remove_values.is_empty() {
                items.push(Widget::Dropdown(Dropdown {
                    title: remove_title,
                    subtitle: remove_subtitle,
                    values: remove_values,
                    setting: "whitelist_remove",
                }));
            }

            if !add_values.is_empty() {
                items.push(Widget::Dropdown(Dropdown {
                    title: "Add to whitelist",
                    subtitle: None,
                    values: add_values,
                    setting: "whitelist_add",
                }));
            }

            widgets.push(Widget::Group(Group {
                title: group_title,
                subtitle: Some(zone_whitelist),
                collapsable: false,
                items: items,
            }));
        }

        Layout {
            settings,
            widgets,
            has_error,
        }
    }
}
