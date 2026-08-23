mod auth;
mod client;
mod worker;

pub use auth::{
    PendingAuthorization, StoredToken, TokenStore, authorization_request, authorize,
    refresh_access_token,
};
pub use client::SpotifyClient;
pub use worker::{SpotifyNotification, run_unavailable_worker, run_worker};

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum MediaKind {
    #[default]
    Track,
    Album,
    Artist,
    Playlist,
    Show,
    Episode,
    Audiobook,
}

impl MediaKind {
    pub const SEARCH_TYPES: &'static str = "track,album,artist,playlist,show,episode,audiobook";

    pub const LIBRARY_TYPES: [Self; 5] = [
        Self::Track,
        Self::Album,
        Self::Episode,
        Self::Show,
        Self::Audiobook,
    ];

    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Track => "track",
            Self::Album => "album",
            Self::Artist => "artist",
            Self::Playlist => "playlist",
            Self::Show => "show",
            Self::Episode => "episode",
            Self::Audiobook => "audiobook",
        }
    }

    fn search_key(self) -> &'static str {
        match self {
            Self::Track => "tracks",
            Self::Album => "albums",
            Self::Artist => "artists",
            Self::Playlist => "playlists",
            Self::Show => "shows",
            Self::Episode => "episodes",
            Self::Audiobook => "audiobooks",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MediaItem {
    pub uri: String,
    pub name: String,
    pub subtitle: String,
    pub kind: MediaKind,
    pub image_url: Option<String>,
    pub duration_ms: Option<u64>,
}

pub fn parse_search_results(json: &str) -> Result<Vec<MediaItem>> {
    let root: Value = serde_json::from_str(json).context("invalid Spotify search response")?;
    let mut results = Vec::new();
    for kind in [
        MediaKind::Track,
        MediaKind::Album,
        MediaKind::Artist,
        MediaKind::Playlist,
        MediaKind::Show,
        MediaKind::Episode,
        MediaKind::Audiobook,
    ] {
        let Some(items) = root
            .get(kind.search_key())
            .and_then(|page| page.get("items"))
            .and_then(Value::as_array)
        else {
            continue;
        };
        results.extend(items.iter().filter_map(|item| normalize_item(item, kind)));
    }
    Ok(results)
}

pub fn parse_page(json: &str, kind: MediaKind) -> Result<Vec<MediaItem>> {
    let root = parse_page_root(json)?;
    let items = page_items(&root)?;
    Ok(items
        .iter()
        .filter_map(|value| {
            let value = unwrap_saved_item(value, kind);
            normalize_item(value, kind)
        })
        .collect())
}

pub fn parse_mixed_page(json: &str) -> Result<Vec<MediaItem>> {
    let root = parse_page_root(json)?;
    let items = page_items(&root)?;
    Ok(items
        .iter()
        .filter_map(|wrapper| {
            let value = wrapper.get("item").unwrap_or(wrapper);
            let kind = match value.get("type").and_then(Value::as_str)? {
                "track" => MediaKind::Track,
                "episode" => MediaKind::Episode,
                _ => return None,
            };
            normalize_item(value, kind)
        })
        .collect())
}

fn parse_page_root(json: &str) -> Result<Value> {
    serde_json::from_str(json).context("invalid Spotify page response")
}

fn page_items(root: &Value) -> Result<&Vec<Value>> {
    root.get("items")
        .and_then(Value::as_array)
        .context("Spotify response has no items")
}

fn unwrap_saved_item(value: &Value, kind: MediaKind) -> &Value {
    value
        .get(kind.as_str())
        .or_else(|| value.get("item"))
        .unwrap_or(value)
}

fn normalize_item(value: &Value, kind: MediaKind) -> Option<MediaItem> {
    let uri = value.get("uri")?.as_str()?.to_owned();
    let name = value.get("name")?.as_str()?.to_owned();
    let subtitle = match kind {
        MediaKind::Track | MediaKind::Album => joined_names(value.get("artists"), "name"),
        MediaKind::Artist => "Artist".to_owned(),
        MediaKind::Playlist => value
            .pointer("/owner/display_name")
            .and_then(Value::as_str)
            .unwrap_or("Spotify playlist")
            .to_owned(),
        MediaKind::Show => value
            .get("publisher")
            .and_then(Value::as_str)
            .unwrap_or("Podcast")
            .to_owned(),
        MediaKind::Episode => value
            .pointer("/show/publisher")
            .and_then(Value::as_str)
            .unwrap_or("Episode")
            .to_owned(),
        MediaKind::Audiobook => joined_names(value.get("authors"), "name"),
    };
    let images = if kind == MediaKind::Track {
        value.pointer("/album/images")
    } else {
        value.get("images")
    };
    let image_url = images
        .and_then(Value::as_array)
        .and_then(|images| images.last())
        .and_then(|image| image.get("url"))
        .and_then(Value::as_str)
        .map(str::to_owned);

    Some(MediaItem {
        uri,
        name,
        subtitle,
        kind,
        image_url,
        duration_ms: value.get("duration_ms").and_then(Value::as_u64),
    })
}

fn joined_names(value: Option<&Value>, field: &str) -> String {
    let names = value
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(|entry| entry.get(field).and_then(Value::as_str))
        .collect::<Vec<_>>();
    if names.is_empty() {
        "Spotify".to_owned()
    } else {
        names.join(", ")
    }
}
