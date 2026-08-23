use crossterm::event::{KeyCode, KeyEvent, KeyEventKind};

use crate::{
    app::{AppState, InputMode, Tab},
    soloist::{PlaybackStatus, RepeatMode, SoloistCommand},
    spotify::MediaKind,
};

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Action {
    Quit,
    Soloist(SoloistCommand),
    Spotify(SpotifyRequest),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SpotifyRequest {
    Search(String),
    LoadLibrary(MediaKind),
    LoadPlaylists,
    LoadPlaylistItems(String),
    Save(String),
    Remove(String),
}

pub fn handle_key(app: &mut AppState, key: KeyEvent, now_ms: u64) -> Vec<Action> {
    if key.kind == KeyEventKind::Release {
        return Vec::new();
    }
    if app.input_mode == InputMode::Search {
        return handle_search_key(app, key);
    }

    match key.code {
        KeyCode::Char('q') => vec![Action::Quit],
        KeyCode::Char('1') => switch_tab(app, Tab::NowPlaying),
        KeyCode::Char('2') => switch_tab(app, Tab::Queue),
        KeyCode::Char('3') => switch_tab(app, Tab::Search),
        KeyCode::Char('4') => switch_tab(app, Tab::Library),
        KeyCode::Char('5') => switch_tab(app, Tab::Playlists),
        KeyCode::Char('/') => {
            app.set_tab(Tab::Search);
            app.input_mode = InputMode::Search;
            Vec::new()
        }
        KeyCode::Up | KeyCode::Char('k') => {
            app.move_selection(-1);
            Vec::new()
        }
        KeyCode::Down | KeyCode::Char('j') => {
            app.move_selection(1);
            Vec::new()
        }
        KeyCode::Enter => app
            .selected_uri()
            .map(|uri| Action::Soloist(SoloistCommand::play_uri(uri)))
            .into_iter()
            .collect(),
        KeyCode::Char(' ') => match app.playback.status {
            PlaybackStatus::Playing => vec![Action::Soloist(SoloistCommand::pause())],
            _ => vec![Action::Soloist(SoloistCommand::play())],
        },
        KeyCode::Char('n') => vec![Action::Soloist(SoloistCommand::skip_next())],
        KeyCode::Char('p') => vec![Action::Soloist(SoloistCommand::skip_prev())],
        KeyCode::Left => vec![Action::Soloist(SoloistCommand::seek(
            app.playback.position_at(now_ms).saturating_sub(10_000),
        ))],
        KeyCode::Right => vec![Action::Soloist(SoloistCommand::seek(
            app.playback.position_at(now_ms).saturating_add(10_000),
        ))],
        KeyCode::Char('+') | KeyCode::Char('=') => vec![Action::Soloist(
            SoloistCommand::set_volume(app.playback.volume.saturating_add(5)),
        )],
        KeyCode::Char('-') => vec![Action::Soloist(SoloistCommand::set_volume(
            app.playback.volume.saturating_sub(5),
        ))],
        KeyCode::Char('s') => vec![Action::Soloist(SoloistCommand::set_shuffle(
            !app.playback.options.shuffle,
        ))],
        KeyCode::Char('r') => repeat_actions(app.playback.repeat_mode()),
        KeyCode::Char('a') => app
            .selected_uri()
            .filter(|uri| uri.starts_with("spotify:track:"))
            .map(|uri| Action::Soloist(SoloistCommand::add_to_queue(uri)))
            .into_iter()
            .collect(),
        KeyCode::Char('l') => app
            .selected_uri()
            .map(|uri| Action::Spotify(SpotifyRequest::Save(uri.to_owned())))
            .into_iter()
            .collect(),
        KeyCode::Char('d') => app
            .selected_uri()
            .map(|uri| Action::Spotify(SpotifyRequest::Remove(uri.to_owned())))
            .into_iter()
            .collect(),
        KeyCode::Char('[') if app.active_tab == Tab::Library => {
            let kind = app.cycle_library_kind(-1);
            vec![Action::Spotify(SpotifyRequest::LoadLibrary(kind))]
        }
        KeyCode::Char(']') if app.active_tab == Tab::Library => {
            let kind = app.cycle_library_kind(1);
            vec![Action::Spotify(SpotifyRequest::LoadLibrary(kind))]
        }
        KeyCode::Char('g') => refresh_actions(app),
        _ => Vec::new(),
    }
}

fn handle_search_key(app: &mut AppState, key: KeyEvent) -> Vec<Action> {
    match key.code {
        KeyCode::Esc => {
            app.input_mode = InputMode::Normal;
            Vec::new()
        }
        KeyCode::Enter => {
            app.input_mode = InputMode::Normal;
            let query = app.search_query.trim();
            if query.is_empty() {
                Vec::new()
            } else {
                vec![Action::Spotify(SpotifyRequest::Search(query.to_owned()))]
            }
        }
        KeyCode::Backspace => {
            app.search_query.pop();
            Vec::new()
        }
        KeyCode::Char(character) => {
            app.search_query.push(character);
            Vec::new()
        }
        _ => Vec::new(),
    }
}

fn switch_tab(app: &mut AppState, tab: Tab) -> Vec<Action> {
    app.set_tab(tab);
    match tab {
        Tab::Library if app.library_items.is_empty() => {
            vec![Action::Spotify(SpotifyRequest::LoadLibrary(
                app.library_kind,
            ))]
        }
        Tab::Playlists if app.playlists.is_empty() => {
            vec![Action::Spotify(SpotifyRequest::LoadPlaylists)]
        }
        _ => Vec::new(),
    }
}

fn refresh_actions(app: &AppState) -> Vec<Action> {
    match app.active_tab {
        Tab::Library => vec![Action::Spotify(SpotifyRequest::LoadLibrary(
            app.library_kind,
        ))],
        Tab::Playlists => vec![Action::Spotify(SpotifyRequest::LoadPlaylists)],
        Tab::Queue => vec![Action::Soloist(SoloistCommand::get_queue(80))],
        Tab::NowPlaying => vec![Action::Soloist(SoloistCommand::get_state())],
        Tab::Search => app
            .search_query
            .trim()
            .is_empty()
            .then(Vec::new)
            .unwrap_or_else(|| {
                vec![Action::Spotify(SpotifyRequest::Search(
                    app.search_query.trim().to_owned(),
                ))]
            }),
    }
}

fn repeat_actions(mode: RepeatMode) -> Vec<Action> {
    match mode {
        RepeatMode::Off => vec![
            Action::Soloist(SoloistCommand::set_repeat_track(false)),
            Action::Soloist(SoloistCommand::set_repeat_context(true)),
        ],
        RepeatMode::Context => vec![
            Action::Soloist(SoloistCommand::set_repeat_context(false)),
            Action::Soloist(SoloistCommand::set_repeat_track(true)),
        ],
        RepeatMode::Track => vec![
            Action::Soloist(SoloistCommand::set_repeat_track(false)),
            Action::Soloist(SoloistCommand::set_repeat_context(false)),
        ],
    }
}
