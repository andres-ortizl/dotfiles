use anyhow::{Context, Result, bail};
use reqwest::{Client, Method, Response};
use url::Url;

use super::{MediaItem, MediaKind, parse_mixed_page, parse_page, parse_search_results};

const SPOTIFY_API_BASE: &str = "https://api.spotify.com/v1/";

#[derive(Debug, Clone)]
pub struct SpotifyClient {
    http: Client,
    base_url: Url,
    access_token: String,
}

impl SpotifyClient {
    pub fn new(access_token: impl Into<String>) -> Result<Self> {
        let base_url = Url::parse(SPOTIFY_API_BASE).context("invalid Spotify API base URL")?;
        Ok(Self::with_base_url(access_token, base_url))
    }

    pub fn with_base_url(access_token: impl Into<String>, base_url: Url) -> Self {
        Self {
            http: Client::new(),
            base_url,
            access_token: access_token.into(),
        }
    }

    pub async fn search(&self, query: &str) -> Result<Vec<MediaItem>> {
        let response = self
            .request(Method::GET, "search")?
            .query(&[
                ("q", query),
                ("type", MediaKind::SEARCH_TYPES),
                ("limit", "10"),
            ])
            .send()
            .await
            .context("Spotify search request failed")?;
        let body = response_text(response).await?;
        parse_search_results(&body)
    }

    pub async fn playlists(&self) -> Result<Vec<MediaItem>> {
        let response = self
            .request(Method::GET, "me/playlists")?
            .query(&[("limit", "50")])
            .send()
            .await
            .context("Spotify playlists request failed")?;
        parse_page(&response_text(response).await?, MediaKind::Playlist)
    }

    pub async fn library(&self, kind: MediaKind) -> Result<Vec<MediaItem>> {
        let path = match kind {
            MediaKind::Track => "me/tracks",
            MediaKind::Album => "me/albums",
            MediaKind::Episode => "me/episodes",
            MediaKind::Show => "me/shows",
            MediaKind::Audiobook => "me/audiobooks",
            MediaKind::Artist | MediaKind::Playlist => {
                bail!("{} is not a Spotify library item type", kind.as_str())
            }
        };
        let response = self
            .request(Method::GET, path)?
            .query(&[("limit", "50")])
            .send()
            .await
            .with_context(|| format!("Spotify {} library request failed", kind.as_str()))?;
        parse_page(&response_text(response).await?, kind)
    }

    pub async fn playlist_items(&self, playlist_id: &str) -> Result<Vec<MediaItem>> {
        let response = self
            .request(Method::GET, &format!("playlists/{playlist_id}/items"))?
            .query(&[("limit", "50"), ("additional_types", "track,episode")])
            .send()
            .await
            .context("Spotify playlist items request failed")?;
        parse_mixed_page(&response_text(response).await?)
    }

    pub async fn save_to_library(&self, uri: &str) -> Result<()> {
        self.modify_library(Method::PUT, uri).await
    }

    pub async fn remove_from_library(&self, uri: &str) -> Result<()> {
        self.modify_library(Method::DELETE, uri).await
    }

    async fn modify_library(&self, method: Method, uri: &str) -> Result<()> {
        let response = self
            .request(method, "me/library")?
            .query(&[("uris", uri)])
            .send()
            .await
            .context("Spotify library update failed")?;
        response_text(response).await?;
        Ok(())
    }

    fn request(&self, method: Method, path: &str) -> Result<reqwest::RequestBuilder> {
        let url = self
            .base_url
            .join(path)
            .context("invalid Spotify API path")?;
        Ok(self
            .http
            .request(method, url)
            .bearer_auth(&self.access_token))
    }
}

async fn response_text(response: Response) -> Result<String> {
    let status = response.status();
    let body = response
        .text()
        .await
        .context("failed to read Spotify response")?;
    if !status.is_success() {
        bail!("Spotify API returned {status}: {body}");
    }
    Ok(body)
}
