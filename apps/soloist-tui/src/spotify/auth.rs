use std::{
    fs::{self, OpenOptions},
    io::{ErrorKind, Write},
    os::unix::fs::{OpenOptionsExt, PermissionsExt},
    path::PathBuf,
    time::{SystemTime, UNIX_EPOCH},
};

use anyhow::{Context, Result, bail};
use oauth2::{
    AuthUrl, AuthorizationCode, ClientId, CsrfToken, PkceCodeChallenge, PkceCodeVerifier,
    RedirectUrl, RefreshToken, Scope, TokenResponse, TokenUrl, basic::BasicClient,
};
use serde::{Deserialize, Serialize};
use tokio::{
    io::{AsyncReadExt, AsyncWriteExt},
    net::TcpListener,
};
use url::Url;

const AUTHORIZE_URL: &str = "https://accounts.spotify.com/authorize";

const SCOPES: &[&str] = &[
    "playlist-read-private",
    "playlist-read-collaborative",
    "playlist-modify-private",
    "playlist-modify-public",
    "user-follow-modify",
    "user-library-read",
    "user-library-modify",
    "user-read-playback-position",
    "user-read-private",
];

pub struct PendingAuthorization {
    csrf_state: String,
    pkce_verifier: String,
    redirect_uri: String,
}

impl PendingAuthorization {
    pub fn csrf_state(&self) -> &str {
        &self.csrf_state
    }
}

pub fn authorization_request(
    client_id: &str,
    redirect_uri: &str,
) -> Result<(Url, PendingAuthorization)> {
    let client = BasicClient::new(ClientId::new(client_id.to_owned()))
        .set_auth_uri(AuthUrl::new(AUTHORIZE_URL.to_owned())?)
        .set_redirect_uri(RedirectUrl::new(redirect_uri.to_owned())?);
    let (challenge, verifier) = PkceCodeChallenge::new_random_sha256();
    let mut request = client
        .authorize_url(CsrfToken::new_random)
        .set_pkce_challenge(challenge);
    for scope in SCOPES {
        request = request.add_scope(Scope::new((*scope).to_owned()));
    }
    let (url, csrf) = request.url();

    Ok((
        url,
        PendingAuthorization {
            csrf_state: csrf.secret().to_owned(),
            pkce_verifier: verifier.secret().to_owned(),
            redirect_uri: redirect_uri.to_owned(),
        },
    ))
}

pub async fn authorize(client_id: &str, redirect_uri: &str) -> Result<StoredToken> {
    let (redirect, listener) = callback_listener(redirect_uri).await?;
    let (url, pending) = authorization_request(client_id, redirect_uri)?;
    open_authorization_url(&url);

    let (mut stream, callback) = receive_callback(&listener, &redirect).await?;
    let code = match callback_code(&callback, &pending) {
        Ok(code) => code,
        Err(error) => {
            send_callback_response(&mut stream, false).await?;
            return Err(error);
        }
    };
    let token = exchange_code(client_id, code, pending).await;
    send_callback_response(&mut stream, token.is_ok()).await?;
    token
}

async fn callback_listener(redirect_uri: &str) -> Result<(Url, TcpListener)> {
    let redirect = Url::parse(redirect_uri).context("invalid Spotify redirect URI")?;
    if redirect.host_str() != Some("127.0.0.1") {
        bail!("Spotify redirect URI must use 127.0.0.1");
    }
    let port = redirect
        .port()
        .context("Spotify redirect URI must include an explicit port")?;
    let listener = TcpListener::bind(("127.0.0.1", port))
        .await
        .with_context(|| format!("failed to listen for Spotify OAuth on port {port}"))?;
    Ok((redirect, listener))
}

fn open_authorization_url(url: &Url) {
    println!("Open this URL to authorize soloist-tui:\n\n{url}\n");
    let _ = std::process::Command::new("xdg-open")
        .arg(url.as_str())
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .spawn();
}

async fn receive_callback(
    listener: &TcpListener,
    redirect: &Url,
) -> Result<(tokio::net::TcpStream, Url)> {
    let (mut stream, _) = listener.accept().await?;
    let mut request = vec![0; 16 * 1024];
    let size = stream.read(&mut request).await?;
    let request = std::str::from_utf8(&request[..size]).context("invalid OAuth callback")?;
    let target = request
        .lines()
        .next()
        .and_then(|line| line.split_whitespace().nth(1))
        .context("invalid OAuth callback request")?;
    let callback = redirect
        .join(target)
        .context("invalid OAuth callback URL")?;
    if callback.origin() != redirect.origin() || callback.path() != redirect.path() {
        bail!("Spotify authorization returned to an unexpected address");
    }
    Ok((stream, callback))
}

fn callback_code(callback: &Url, pending: &PendingAuthorization) -> Result<String> {
    let parameters = callback
        .query_pairs()
        .collect::<std::collections::HashMap<_, _>>();
    if let Some(error) = parameters.get("error") {
        bail!("Spotify authorization failed: {error}");
    }
    if parameters.get("state").map(|state| state.as_ref()) != Some(pending.csrf_state()) {
        bail!("Spotify authorization returned an invalid state");
    }
    parameters
        .get("code")
        .context("Spotify authorization returned no code")
        .map(ToString::to_string)
}

pub async fn refresh_access_token(client_id: &str, token: &StoredToken) -> Result<StoredToken> {
    let refresh_token = token
        .refresh_token
        .as_ref()
        .context("Spotify token cannot be refreshed; run `soloist-tui auth`")?;
    let client = BasicClient::new(ClientId::new(client_id.to_owned())).set_token_uri(
        TokenUrl::new("https://accounts.spotify.com/api/token".to_owned())?,
    );
    let http = oauth_http_client()?;
    let response = client
        .exchange_refresh_token(&RefreshToken::new(refresh_token.to_owned()))
        .request_async(&http)
        .await
        .context("failed to refresh Spotify token")?;
    Ok(stored_token(response, Some(refresh_token.to_owned())))
}

async fn exchange_code(
    client_id: &str,
    code: String,
    pending: PendingAuthorization,
) -> Result<StoredToken> {
    let client = BasicClient::new(ClientId::new(client_id.to_owned()))
        .set_token_uri(TokenUrl::new(
            "https://accounts.spotify.com/api/token".to_owned(),
        )?)
        .set_redirect_uri(RedirectUrl::new(pending.redirect_uri)?);
    let http = oauth_http_client()?;
    let response = client
        .exchange_code(AuthorizationCode::new(code))
        .set_pkce_verifier(PkceCodeVerifier::new(pending.pkce_verifier))
        .request_async(&http)
        .await
        .context("failed to exchange Spotify authorization code")?;
    Ok(stored_token(response, None))
}

fn stored_token(
    response: oauth2::basic::BasicTokenResponse,
    previous_refresh_token: Option<String>,
) -> StoredToken {
    let expires_in = response
        .expires_in()
        .map_or(3600, |duration| duration.as_secs());
    StoredToken {
        access_token: response.access_token().secret().to_owned(),
        refresh_token: response
            .refresh_token()
            .map(|token| token.secret().to_owned())
            .or(previous_refresh_token),
        expires_at: unix_time().saturating_add(expires_in),
    }
}

fn oauth_http_client() -> Result<reqwest::Client> {
    reqwest::Client::builder()
        .redirect(reqwest::redirect::Policy::none())
        .build()
        .context("failed to create OAuth HTTP client")
}

async fn send_callback_response(stream: &mut tokio::net::TcpStream, success: bool) -> Result<()> {
    let message = if success {
        "Spotify connected. You can close this window."
    } else {
        "Spotify authorization failed. Return to the terminal."
    };
    let response = format!(
        "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
        message.len(),
        message
    );
    stream.write_all(response.as_bytes()).await?;
    Ok(())
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct StoredToken {
    pub access_token: String,
    pub refresh_token: Option<String>,
    pub expires_at: u64,
}

impl StoredToken {
    pub fn expires_soon(&self) -> bool {
        unix_time().saturating_add(60) >= self.expires_at
    }
}

#[derive(Debug, Clone)]
pub struct TokenStore {
    path: PathBuf,
}

impl TokenStore {
    pub fn new(path: PathBuf) -> Self {
        Self { path }
    }

    pub fn load(&self) -> Result<Option<StoredToken>> {
        let content = match fs::read_to_string(&self.path) {
            Ok(content) => content,
            Err(error) if error.kind() == ErrorKind::NotFound => return Ok(None),
            Err(error) => {
                return Err(error)
                    .with_context(|| format!("failed to read {}", self.path.display()));
            }
        };
        serde_json::from_str(&content)
            .with_context(|| format!("invalid token data in {}", self.path.display()))
            .map(Some)
    }

    pub fn save(&self, token: &StoredToken) -> Result<()> {
        let parent = self.path.parent().context("token path has no parent")?;
        fs::create_dir_all(parent)
            .with_context(|| format!("failed to create {}", parent.display()))?;
        fs::set_permissions(parent, fs::Permissions::from_mode(0o700))
            .with_context(|| format!("failed to secure {}", parent.display()))?;

        let temporary = self.path.with_extension("json.tmp");
        let mut file = OpenOptions::new()
            .create(true)
            .truncate(true)
            .write(true)
            .mode(0o600)
            .open(&temporary)
            .with_context(|| format!("failed to write {}", temporary.display()))?;
        serde_json::to_writer(&mut file, token).context("failed to encode Spotify token")?;
        file.write_all(b"\n")?;
        file.sync_all()?;
        fs::rename(&temporary, &self.path)
            .with_context(|| format!("failed to replace {}", self.path.display()))?;
        fs::set_permissions(&self.path, fs::Permissions::from_mode(0o600))?;
        Ok(())
    }
}

fn unix_time() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}
