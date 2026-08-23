use std::{
    io::{self, Stdout},
    time::{Duration, SystemTime, UNIX_EPOCH},
};

use anyhow::{Context, Result};
use crossterm::{
    event::{DisableMouseCapture, EnableMouseCapture, Event, EventStream},
    execute,
    terminal::{EnterAlternateScreen, LeaveAlternateScreen, disable_raw_mode, enable_raw_mode},
};
use futures_util::StreamExt;
use ratatui::{Terminal, backend::CrosstermBackend};
use tokio::sync::mpsc;

use crate::{
    app::{AppState, ConnectionStatus},
    config::Config,
    input::{Action, handle_key},
    soloist::{SoloistCommand, SoloistNotification, run_manager},
    spotify::{StoredToken, TokenStore, run_unavailable_worker, run_worker},
    ui,
};

pub async fn run(
    config: Config,
    token: Option<StoredToken>,
    token_store: TokenStore,
) -> Result<()> {
    let (soloist_commands, soloist_command_rx) = mpsc::channel(64);
    let (soloist_notifications, mut soloist_notification_rx) = mpsc::channel(64);
    let (spotify_requests, spotify_request_rx) = mpsc::channel(32);
    let (spotify_notifications, mut spotify_notification_rx) = mpsc::channel(32);

    tokio::spawn(run_manager(
        config.soloist_data_dir.clone(),
        soloist_command_rx,
        soloist_notifications,
    ));
    let spotify_available = config.spotify_is_configured() && token.is_some();
    if let Some(token) = token.filter(|_| config.spotify_is_configured()) {
        tokio::spawn(run_worker(
            config.spotify_client_id.clone(),
            token_store,
            token,
            spotify_request_rx,
            spotify_notifications,
        ));
    } else {
        tokio::spawn(run_unavailable_worker(
            spotify_request_rx,
            spotify_notifications,
        ));
    }

    let mut terminal = TerminalSession::new()?;
    let mut events = EventStream::new();
    let mut tick = tokio::time::interval(Duration::from_millis(250));
    tick.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
    let mut app = AppState::default();
    app.soloist_connection = ConnectionStatus::Connecting;
    app.spotify_authenticated = spotify_available;
    if !spotify_available {
        app.status_message = Some(
            "Soloist-only mode. Configure Spotify Web API and run `soloist-tui auth` for Search and Library."
                .into(),
        );
    }
    let mut dirty = true;

    soloist_commands
        .send(SoloistCommand::get_state())
        .await
        .ok();
    soloist_commands
        .send(SoloistCommand::get_queue(80))
        .await
        .ok();

    loop {
        if dirty {
            let now = unix_time_ms();
            terminal
                .terminal
                .draw(|frame| ui::render(frame, &app, now))
                .context("failed to render terminal")?;
            dirty = false;
        }

        tokio::select! {
            terminal_event = events.next() => {
                match terminal_event {
                    Some(Ok(Event::Key(key))) => {
                        let actions = handle_key(&mut app, key, unix_time_ms());
                        if dispatch_actions(actions, &soloist_commands, &spotify_requests).await? {
                            return Ok(());
                        }
                        dirty = true;
                    }
                    Some(Ok(Event::Resize(_, _))) => dirty = true,
                    Some(Ok(_)) => {}
                    Some(Err(error)) => return Err(error).context("failed to read terminal event"),
                    None => return Ok(()),
                }
            }
            notification = soloist_notification_rx.recv() => {
                let Some(notification) = notification else {
                    return Ok(());
                };
                apply_soloist_notification(&mut app, notification, &soloist_commands).await;
                dirty = true;
            }
            notification = spotify_notification_rx.recv() => {
                let Some(notification) = notification else {
                    return Ok(());
                };
                app.apply_spotify_notification(notification);
                dirty = true;
            }
            _ = tick.tick() => {
                if app.playback.status == crate::soloist::PlaybackStatus::Playing {
                    dirty = true;
                }
            }
            result = tokio::signal::ctrl_c() => {
                result.context("failed to listen for Ctrl-C")?;
                return Ok(());
            }
        }
    }
}

async fn dispatch_actions(
    actions: Vec<Action>,
    soloist: &mpsc::Sender<SoloistCommand>,
    spotify: &mpsc::Sender<crate::input::SpotifyRequest>,
) -> Result<bool> {
    for action in actions {
        match action {
            Action::Quit => return Ok(true),
            Action::Soloist(command) => soloist
                .send(command)
                .await
                .context("Soloist command channel closed")?,
            Action::Spotify(request) => spotify
                .send(request)
                .await
                .context("Spotify request channel closed")?,
        }
    }
    Ok(false)
}

async fn apply_soloist_notification(
    app: &mut AppState,
    notification: SoloistNotification,
    commands: &mpsc::Sender<SoloistCommand>,
) {
    match notification {
        SoloistNotification::Connecting => {
            app.set_soloist_connection(ConnectionStatus::Connecting);
        }
        SoloistNotification::Connected => {
            app.set_soloist_connection(ConnectionStatus::Connected);
            app.status_message = None;
            commands.send(SoloistCommand::get_state()).await.ok();
            commands.send(SoloistCommand::get_queue(80)).await.ok();
        }
        SoloistNotification::Event(event) => app.apply_soloist_event(*event),
        SoloistNotification::Disconnected(reason) => {
            app.set_soloist_connection(ConnectionStatus::Disconnected);
            app.status_message = Some(reason);
        }
    }
}

struct TerminalSession {
    terminal: Terminal<CrosstermBackend<Stdout>>,
}

impl TerminalSession {
    fn new() -> Result<Self> {
        enable_raw_mode().context("failed to enable terminal raw mode")?;
        let mut stdout = io::stdout();
        if let Err(error) = execute!(stdout, EnterAlternateScreen, EnableMouseCapture) {
            disable_raw_mode().ok();
            return Err(error).context("failed to enter alternate screen");
        }
        let terminal = Terminal::new(CrosstermBackend::new(stdout))?;
        Ok(Self { terminal })
    }
}

impl Drop for TerminalSession {
    fn drop(&mut self) {
        disable_raw_mode().ok();
        execute!(
            self.terminal.backend_mut(),
            LeaveAlternateScreen,
            DisableMouseCapture
        )
        .ok();
        self.terminal.show_cursor().ok();
    }
}

fn unix_time_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as u64
}
