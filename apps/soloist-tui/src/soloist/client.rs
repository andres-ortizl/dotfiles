use std::{path::PathBuf, time::Duration};

use anyhow::{Context, Result};
use futures_util::{SinkExt, StreamExt};
use tokio::sync::mpsc;
use tokio_tungstenite::{connect_async, tungstenite::Message};
use url::Url;

use super::{SoloistCommand, SoloistEvent, discover_endpoint};

#[derive(Debug, Clone, PartialEq)]
pub enum SoloistNotification {
    Connecting,
    Connected,
    Event(Box<SoloistEvent>),
    Disconnected(String),
}

pub async fn run_manager(
    data_dir: PathBuf,
    mut commands: mpsc::Receiver<SoloistCommand>,
    notifications: mpsc::Sender<SoloistNotification>,
) {
    loop {
        if notifications
            .send(SoloistNotification::Connecting)
            .await
            .is_err()
        {
            return;
        }
        match discover_endpoint(&data_dir).await {
            Ok(endpoint) => {
                if let Err(error) =
                    run_connection(endpoint, &mut commands, notifications.clone()).await
                {
                    let _ = notifications
                        .send(SoloistNotification::Disconnected(format!("{error:#}")))
                        .await;
                }
            }
            Err(error) => {
                let _ = notifications
                    .send(SoloistNotification::Disconnected(format!("{error:#}")))
                    .await;
            }
        }
        if commands.is_closed() {
            return;
        }
        tokio::time::sleep(Duration::from_secs(2)).await;
    }
}

pub async fn run_connection(
    endpoint: Url,
    commands: &mut mpsc::Receiver<SoloistCommand>,
    notifications: mpsc::Sender<SoloistNotification>,
) -> Result<()> {
    let (socket, _) = connect_async(endpoint.as_str())
        .await
        .with_context(|| format!("failed to connect to Soloist at {endpoint}"))?;
    let (mut writer, mut reader) = socket.split();
    notifications
        .send(SoloistNotification::Connected)
        .await
        .context("Soloist notification receiver closed")?;

    loop {
        tokio::select! {
            command = commands.recv() => {
                let Some(command) = command else {
                    return Ok(());
                };
                writer
                    .send(Message::Text(command.to_json()?.into()))
                    .await
                    .context("failed to send command to Soloist")?;
            }
            message = reader.next() => {
                let Some(message) = message else {
                    notifications
                        .send(SoloistNotification::Disconnected("Soloist closed the connection".into()))
                        .await
                        .ok();
                    return Ok(());
                };
                let message = message.context("failed to read from Soloist")?;
                if let Message::Text(json) = message {
                    match SoloistEvent::from_json(&json) {
                        Ok(event) => {
                            if notifications
                                .send(SoloistNotification::Event(Box::new(event)))
                                .await
                                .is_err()
                            {
                                return Ok(());
                            }
                        }
                        Err(error) => tracing::warn!(%error, "ignored invalid Soloist event"),
                    }
                }
            }
        }
    }
}
