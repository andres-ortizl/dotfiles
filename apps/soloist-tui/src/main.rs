use std::path::PathBuf;

use anyhow::{Result, bail};
use clap::{Parser, Subcommand};
use soloist_tui::{
    config::Config,
    runtime,
    spotify::{TokenStore, authorize},
};

#[derive(Debug, Parser)]
#[command(
    name = "soloist-tui",
    version,
    about = "A fast Spotify Soloist terminal player"
)]
struct Cli {
    #[arg(long, value_name = "PATH")]
    config: Option<PathBuf>,
    #[command(subcommand)]
    command: Option<Command>,
}

#[derive(Debug, Subcommand)]
enum Command {
    /// Authenticate with Spotify Web API using OAuth PKCE.
    Auth,
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();
    let config_path = cli.config.unwrap_or_else(Config::default_path);
    let config = Config::load_or_local(&config_path)?;
    let token_store = TokenStore::new(Config::token_path());

    match cli.command {
        Some(Command::Auth) => {
            if !config.spotify_is_configured() {
                bail!(
                    "Spotify Web API is not configured. Create {} with:\n\nspotify_client_id = \"YOUR_CLIENT_ID\"\nredirect_uri = \"http://127.0.0.1:8888/callback\"",
                    config_path.display()
                );
            }
            let token = authorize(&config.spotify_client_id, &config.redirect_uri).await?;
            token_store.save(&token)?;
            println!("Spotify authentication saved.");
            Ok(())
        }
        None => {
            let token = if config.spotify_is_configured() {
                token_store.load()?
            } else {
                None
            };
            runtime::run(config, token, token_store).await
        }
    }
}
