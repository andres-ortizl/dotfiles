mod client;

pub use client::{SoloistNotification, run_connection, run_manager};

use serde::{Deserialize, Serialize};
use std::path::Path;

use anyhow::{Context, Result};
use url::Url;

#[derive(Debug, Clone, Deserialize, PartialEq)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum SoloistEvent {
    AuthState(AuthState),
    PlaybackState(Box<PlaybackSnapshot>),
    TrackChanged {
        item: Option<Box<Entity>>,
    },
    PlaybackChanged {
        status: PlaybackStatus,
    },
    VolumeChanged {
        volume: u8,
    },
    DeviceChanged {
        is_active: bool,
        device_name: String,
    },
    ContextChanged {
        context: Option<Box<Entity>>,
    },
    OptionsChanged {
        options: PlaybackOptions,
    },
    PositionSync {
        position: Position,
    },
    QueueChanged(QueueSnapshot),
    CommandResult {
        command: String,
    },
    Error {
        message: String,
    },
    #[serde(other)]
    Unknown,
}

impl SoloistEvent {
    pub fn from_json(json: &str) -> serde_json::Result<Self> {
        serde_json::from_str(json)
    }
}

#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct AuthState {
    pub logged_in: bool,
    pub is_active: bool,
    pub device_name: String,
}

#[derive(Debug, Clone, Deserialize, PartialEq)]
pub struct PlaybackSnapshot {
    pub status: PlaybackStatus,
    pub item: Option<Entity>,
    pub context: Option<Entity>,
    pub position: Position,
    pub volume: u8,
    pub is_active: bool,
    #[serde(default)]
    pub options: PlaybackOptions,
}

#[derive(Debug, Clone, Copy, Default, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum PlaybackStatus {
    #[default]
    Idle,
    Playing,
    Paused,
    Buffering,
}

#[derive(Debug, Clone, Copy, Default, Deserialize, PartialEq)]
pub struct Position {
    #[serde(default)]
    pub position_ms: u64,
    #[serde(default)]
    pub timestamp_ms: u64,
    #[serde(default)]
    pub speed: f64,
}

#[derive(Debug, Clone, Default, Deserialize, PartialEq)]
pub struct PlaybackOptions {
    #[serde(default)]
    pub shuffle: bool,
    #[serde(default, rename = "repeat")]
    pub repeat_mode: RepeatMode,
    #[serde(default = "normal_speed")]
    pub playback_speed: f64,
}

const fn normal_speed() -> f64 {
    1.0
}

#[derive(Debug, Clone, Copy, Default, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum RepeatMode {
    #[default]
    Off,
    Context,
    Track,
}

#[derive(Debug, Clone, Default, Deserialize, PartialEq, Eq)]
pub struct Entity {
    #[serde(default)]
    pub uri: String,
    #[serde(default)]
    pub entity_type: String,
    #[serde(default)]
    pub decorations: Decorations,
}

impl Entity {
    pub fn name(&self) -> &str {
        self.decorations
            .identity
            .as_ref()
            .map_or("Unknown", |identity| identity.name.as_str())
    }

    pub fn creators(&self) -> Vec<&str> {
        self.decorations
            .creators
            .iter()
            .map(|creator| creator.entity.name())
            .collect()
    }

    pub fn duration_ms(&self) -> Option<u64> {
        self.decorations
            .playback
            .as_ref()
            .and_then(|playback| playback.duration_ms)
    }

    pub fn cover_url(&self) -> Option<&str> {
        self.decorations
            .visual_identity
            .as_ref()
            .and_then(|visual| visual.cover.last())
            .map(|cover| cover.url.as_str())
    }
}

#[derive(Debug, Clone, Default, Deserialize, PartialEq, Eq)]
pub struct Decorations {
    #[serde(default)]
    pub identity: Option<Identity>,
    #[serde(default)]
    pub visual_identity: Option<VisualIdentity>,
    #[serde(default)]
    pub parent: Option<Parent>,
    #[serde(default)]
    pub creators: Vec<Creator>,
    #[serde(default)]
    pub playback: Option<PlaybackMetadata>,
}

#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct Identity {
    pub name: String,
}

#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct VisualIdentity {
    #[serde(default)]
    pub cover: Vec<Cover>,
}

#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct Cover {
    pub url: String,
    #[serde(default)]
    pub size: String,
}

#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct Parent {
    pub entity: Box<Entity>,
}

#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct Creator {
    pub entity: Entity,
}

#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct PlaybackMetadata {
    #[serde(default)]
    pub duration_ms: Option<u64>,
    #[serde(default)]
    pub content_ratings: Vec<String>,
}

#[derive(Debug, Clone, Default, Deserialize, PartialEq, Eq)]
pub struct QueueSnapshot {
    #[serde(default)]
    pub previous: Vec<QueueEntry>,
    #[serde(default)]
    pub upcoming: Vec<QueueEntry>,
}

#[derive(Debug, Clone, Deserialize, PartialEq, Eq)]
pub struct QueueEntry {
    pub uid: String,
    #[serde(default)]
    pub source: String,
    pub item: Entity,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
pub struct SoloistCommand {
    #[serde(rename = "type")]
    message_type: &'static str,
    command: &'static str,
    #[serde(skip_serializing_if = "Option::is_none")]
    uri: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    position_ms: Option<u64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    volume: Option<u8>,
    #[serde(skip_serializing_if = "Option::is_none")]
    enabled: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    limit: Option<usize>,
}

impl SoloistCommand {
    fn new(command: &'static str) -> Self {
        Self {
            message_type: "command",
            command,
            uri: None,
            position_ms: None,
            volume: None,
            enabled: None,
            limit: None,
        }
    }

    pub fn get_state() -> Self {
        Self::new("get_state")
    }

    pub fn get_queue(limit: usize) -> Self {
        Self {
            limit: Some(limit),
            ..Self::new("get_queue")
        }
    }

    pub fn play() -> Self {
        Self::new("play")
    }

    pub fn play_uri(uri: impl Into<String>) -> Self {
        Self {
            uri: Some(uri.into()),
            ..Self::new("play")
        }
    }

    pub fn pause() -> Self {
        Self::new("pause")
    }

    pub fn skip_next() -> Self {
        Self::new("skip_next")
    }

    pub fn skip_prev() -> Self {
        Self::new("skip_prev")
    }

    pub fn seek(position_ms: u64) -> Self {
        Self {
            position_ms: Some(position_ms),
            ..Self::new("seek")
        }
    }

    pub fn set_volume(volume: u8) -> Self {
        Self {
            volume: Some(volume.min(100)),
            ..Self::new("set_volume")
        }
    }

    pub fn set_shuffle(enabled: bool) -> Self {
        Self {
            enabled: Some(enabled),
            ..Self::new("set_shuffle")
        }
    }

    pub fn set_repeat_context(enabled: bool) -> Self {
        Self {
            enabled: Some(enabled),
            ..Self::new("set_repeat_context")
        }
    }

    pub fn set_repeat_track(enabled: bool) -> Self {
        Self {
            enabled: Some(enabled),
            ..Self::new("set_repeat_track")
        }
    }

    pub fn add_to_queue(uri: impl Into<String>) -> Self {
        Self {
            uri: Some(uri.into()),
            ..Self::new("add_to_queue")
        }
    }

    pub fn activate() -> Self {
        Self::new("activate")
    }

    pub fn to_json(&self) -> serde_json::Result<String> {
        serde_json::to_string(self)
    }
}

pub async fn discover_endpoint(data_dir: &Path) -> Result<Url> {
    let address = tokio::fs::read_to_string(data_dir.join("ws.addr"))
        .await
        .with_context(|| format!("missing Soloist endpoint in {}", data_dir.display()))?;
    let port = tokio::fs::read_to_string(data_dir.join("ws.port"))
        .await
        .with_context(|| format!("missing Soloist port in {}", data_dir.display()))?;
    let port: u16 = port
        .trim()
        .parse()
        .context("invalid Soloist WebSocket port")?;
    let address = address.trim();
    let host = if address.contains(':') && !address.starts_with('[') {
        format!("[{address}]")
    } else {
        address.to_owned()
    };

    Url::parse(&format!("ws://{host}:{port}")).context("invalid Soloist WebSocket endpoint")
}
