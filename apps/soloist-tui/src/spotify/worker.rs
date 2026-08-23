use anyhow::Result;
use tokio::sync::mpsc;

use crate::input::SpotifyRequest;

use super::{MediaItem, MediaKind, SpotifyClient, StoredToken, TokenStore, refresh_access_token};

#[derive(Debug, Clone)]
pub enum SpotifyNotification {
    Loading,
    SearchResults(Vec<MediaItem>),
    Library {
        kind: MediaKind,
        items: Vec<MediaItem>,
    },
    Playlists(Vec<MediaItem>),
    PlaylistItems(Vec<MediaItem>),
    Saved(String),
    Removed(String),
    Error(String),
}

pub async fn run_unavailable_worker(
    mut requests: mpsc::Receiver<SpotifyRequest>,
    notifications: mpsc::Sender<SpotifyNotification>,
) {
    while requests.recv().await.is_some() {
        if notifications
            .send(SpotifyNotification::Error(
                "Spotify Web API is unavailable. Configure config.toml and run `soloist-tui auth`."
                    .into(),
            ))
            .await
            .is_err()
        {
            return;
        }
    }
}

pub async fn run_worker(
    client_id: String,
    store: TokenStore,
    mut token: StoredToken,
    mut requests: mpsc::Receiver<SpotifyRequest>,
    notifications: mpsc::Sender<SpotifyNotification>,
) {
    while let Some(request) = requests.recv().await {
        let client = match client_for_request(&client_id, &store, &mut token).await {
            Ok(client) => client,
            Err(error) => {
                send_error(&notifications, error).await;
                continue;
            }
        };
        if notifications
            .send(SpotifyNotification::Loading)
            .await
            .is_err()
        {
            return;
        }
        let result = execute(&client, request).await;
        if notifications.send(result).await.is_err() {
            return;
        }
    }
}

async fn client_for_request(
    client_id: &str,
    store: &TokenStore,
    token: &mut StoredToken,
) -> Result<SpotifyClient> {
    if token.expires_soon() {
        *token = refresh_access_token(client_id, token).await?;
        store.save(token)?;
    }
    SpotifyClient::new(&token.access_token)
}

async fn execute(client: &SpotifyClient, request: SpotifyRequest) -> SpotifyNotification {
    let result: Result<SpotifyNotification> = async {
        Ok(match request {
            SpotifyRequest::Search(query) => {
                SpotifyNotification::SearchResults(client.search(&query).await?)
            }
            SpotifyRequest::LoadLibrary(kind) => SpotifyNotification::Library {
                kind,
                items: client.library(kind).await?,
            },
            SpotifyRequest::LoadPlaylists => {
                SpotifyNotification::Playlists(client.playlists().await?)
            }
            SpotifyRequest::LoadPlaylistItems(playlist_id) => {
                SpotifyNotification::PlaylistItems(client.playlist_items(&playlist_id).await?)
            }
            SpotifyRequest::Save(uri) => {
                client.save_to_library(&uri).await?;
                SpotifyNotification::Saved(uri)
            }
            SpotifyRequest::Remove(uri) => {
                client.remove_from_library(&uri).await?;
                SpotifyNotification::Removed(uri)
            }
        })
    }
    .await;
    result.unwrap_or_else(|error| SpotifyNotification::Error(format!("{error:#}")))
}

async fn send_error(notifications: &mpsc::Sender<SpotifyNotification>, error: anyhow::Error) {
    let _ = notifications
        .send(SpotifyNotification::Error(format!("{error:#}")))
        .await;
}
