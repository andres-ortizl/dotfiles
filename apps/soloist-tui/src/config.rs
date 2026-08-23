use std::{
    env,
    path::{Path, PathBuf},
};

use anyhow::{Context, Result};
use serde::Deserialize;

#[derive(Debug, Clone, Deserialize)]
pub struct Config {
    #[serde(default)]
    pub spotify_client_id: String,
    #[serde(default = "default_redirect_uri")]
    pub redirect_uri: String,
    #[serde(default = "default_soloist_data_dir")]
    pub soloist_data_dir: PathBuf,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            spotify_client_id: env::var("SPOTIFY_CLIENT_ID").unwrap_or_default(),
            redirect_uri: default_redirect_uri(),
            soloist_data_dir: default_soloist_data_dir(),
        }
    }
}

impl Config {
    pub fn load(path: &Path) -> Result<Self> {
        let text = std::fs::read_to_string(path)
            .with_context(|| format!("failed to read {}", path.display()))?;
        let mut config: Self = toml::from_str(&text)
            .with_context(|| format!("invalid configuration in {}", path.display()))?;
        if let Ok(client_id) = env::var("SPOTIFY_CLIENT_ID") {
            config.spotify_client_id = client_id;
        }
        Ok(config)
    }

    pub fn load_or_local(path: &Path) -> Result<Self> {
        if path.exists() {
            Self::load(path)
        } else {
            Ok(Self::default())
        }
    }

    pub fn spotify_is_configured(&self) -> bool {
        !self.spotify_client_id.trim().is_empty()
    }

    pub fn default_path() -> PathBuf {
        xdg_dir("XDG_CONFIG_HOME", ".config")
            .join("soloist-tui")
            .join("config.toml")
    }

    pub fn token_path() -> PathBuf {
        xdg_dir("XDG_DATA_HOME", ".local/share")
            .join("soloist-tui")
            .join("token.json")
    }
}

fn default_redirect_uri() -> String {
    "http://127.0.0.1:8888/callback".to_owned()
}

fn default_soloist_data_dir() -> PathBuf {
    xdg_dir("XDG_DATA_HOME", ".local/share").join("soloist")
}

fn xdg_dir(variable: &str, fallback: &str) -> PathBuf {
    env::var_os(variable)
        .map(PathBuf::from)
        .or_else(|| env::var_os("HOME").map(|home| PathBuf::from(home).join(fallback)))
        .unwrap_or_else(|| PathBuf::from(fallback))
}
