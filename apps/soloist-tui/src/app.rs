use crate::{
    soloist::{
        Entity, PlaybackOptions, PlaybackStatus, Position, QueueEntry, RepeatMode, SoloistEvent,
    },
    spotify::{MediaItem, MediaKind, SpotifyNotification},
};

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub enum Tab {
    #[default]
    NowPlaying,
    Queue,
    Search,
    Library,
    Playlists,
}

impl Tab {
    pub const fn index(self) -> usize {
        match self {
            Self::NowPlaying => 0,
            Self::Queue => 1,
            Self::Search => 2,
            Self::Library => 3,
            Self::Playlists => 4,
        }
    }

    pub const fn from_index(index: usize) -> Self {
        match index {
            1 => Self::Queue,
            2 => Self::Search,
            3 => Self::Library,
            4 => Self::Playlists,
            _ => Self::NowPlaying,
        }
    }
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub enum InputMode {
    #[default]
    Normal,
    Search,
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub enum ConnectionStatus {
    #[default]
    Disconnected,
    Connecting,
    Connected,
}

#[derive(Debug, Clone, Default)]
pub struct PlaybackState {
    pub status: PlaybackStatus,
    pub item: Option<Entity>,
    pub context: Option<Entity>,
    pub position: Position,
    pub volume: u8,
    pub is_active: bool,
    pub options: PlaybackOptions,
}

impl PlaybackState {
    pub fn position_at(&self, now_ms: u64) -> u64 {
        let elapsed = if self.status == PlaybackStatus::Playing {
            now_ms.saturating_sub(self.position.timestamp_ms) as f64 * self.position.speed
        } else {
            0.0
        };
        let position = self
            .position
            .position_ms
            .saturating_add(elapsed.max(0.0) as u64);
        self.item
            .as_ref()
            .and_then(Entity::duration_ms)
            .map_or(position, |duration| position.min(duration))
    }

    pub fn repeat_mode(&self) -> RepeatMode {
        self.options.repeat_mode
    }
}

#[derive(Debug, Default)]
pub struct AppState {
    pub active_tab: Tab,
    pub input_mode: InputMode,
    pub soloist_connection: ConnectionStatus,
    pub spotify_authenticated: bool,
    pub spotify_loading: bool,
    pub device_name: String,
    pub logged_in: bool,
    pub playback: PlaybackState,
    pub queue: Vec<QueueEntry>,
    pub search_query: String,
    pub search_results: Vec<MediaItem>,
    pub library_kind: MediaKind,
    pub library_items: Vec<MediaItem>,
    pub playlists: Vec<MediaItem>,
    pub playlist_items: Vec<MediaItem>,
    pub status_message: Option<String>,
    selections: [usize; 5],
}

impl AppState {
    pub fn set_soloist_connection(&mut self, status: ConnectionStatus) {
        self.soloist_connection = status;
    }

    pub fn set_tab(&mut self, tab: Tab) {
        self.active_tab = tab;
        self.input_mode = InputMode::Normal;
    }

    pub fn selection(&self) -> usize {
        self.selections[self.active_tab.index()]
    }

    pub fn move_selection(&mut self, delta: isize) {
        let index = self.active_tab.index();
        let length = self.active_collection_len();
        if length == 0 {
            self.selections[index] = 0;
            return;
        }
        self.selections[index] = self.selections[index]
            .saturating_add_signed(delta)
            .min(length - 1);
    }

    pub fn selected_uri(&self) -> Option<&str> {
        let selected = self.selection();
        match self.active_tab {
            Tab::NowPlaying => self.playback.item.as_ref().map(|item| item.uri.as_str()),
            Tab::Queue => self
                .queue
                .get(selected)
                .map(|entry| entry.item.uri.as_str()),
            Tab::Search => self
                .search_results
                .get(selected)
                .map(|item| item.uri.as_str()),
            Tab::Library => self
                .library_items
                .get(selected)
                .map(|item| item.uri.as_str()),
            Tab::Playlists => self.playlists.get(selected).map(|item| item.uri.as_str()),
        }
    }

    pub fn selected_kind(&self) -> Option<MediaKind> {
        let selected = self.selection();
        match self.active_tab {
            Tab::Search => self.search_results.get(selected).map(|item| item.kind),
            Tab::Library => self.library_items.get(selected).map(|item| item.kind),
            Tab::Playlists => Some(MediaKind::Playlist),
            Tab::NowPlaying | Tab::Queue => None,
        }
    }

    pub fn replace_search_results(&mut self, items: Vec<MediaItem>) {
        self.search_results = items;
        self.selections[Tab::Search.index()] = 0;
    }

    pub fn replace_library(&mut self, kind: MediaKind, items: Vec<MediaItem>) {
        self.library_kind = kind;
        self.library_items = items;
        self.selections[Tab::Library.index()] = 0;
    }

    pub fn cycle_library_kind(&mut self, delta: isize) -> MediaKind {
        let kinds = MediaKind::LIBRARY_TYPES;
        let current = kinds
            .iter()
            .position(|kind| *kind == self.library_kind)
            .unwrap_or_default();
        let next = (current as isize + delta).rem_euclid(kinds.len() as isize) as usize;
        self.library_kind = kinds[next];
        self.library_items.clear();
        self.selections[Tab::Library.index()] = 0;
        self.library_kind
    }

    fn active_collection_len(&self) -> usize {
        match self.active_tab {
            Tab::NowPlaying => usize::from(self.playback.item.is_some()),
            Tab::Queue => self.queue.len(),
            Tab::Search => self.search_results.len(),
            Tab::Library => self.library_items.len(),
            Tab::Playlists => self.playlists.len(),
        }
    }

    pub fn apply_spotify_notification(&mut self, notification: SpotifyNotification) {
        self.spotify_loading = matches!(&notification, SpotifyNotification::Loading);
        match notification {
            SpotifyNotification::Loading => self.status_message = Some("Loading Spotify…".into()),
            SpotifyNotification::SearchResults(items) => {
                self.replace_search_results(items);
                self.status_message = None;
            }
            SpotifyNotification::Library { kind, items } => {
                self.replace_library(kind, items);
                self.status_message = None;
            }
            SpotifyNotification::Playlists(items) => {
                self.playlists = items;
                self.selections[Tab::Playlists.index()] = 0;
                self.status_message = None;
            }
            SpotifyNotification::PlaylistItems(items) => {
                self.playlist_items = items;
                self.status_message = None;
            }
            SpotifyNotification::Saved(uri) => {
                self.status_message = Some(format!("Saved {uri}"));
            }
            SpotifyNotification::Removed(uri) => {
                self.status_message = Some(format!("Removed {uri}"));
            }
            SpotifyNotification::Error(error) => self.status_message = Some(error),
        }
    }

    pub fn apply_soloist_event(&mut self, event: SoloistEvent) {
        match event {
            SoloistEvent::AuthState(auth) => {
                self.logged_in = auth.logged_in;
                self.device_name = auth.device_name;
                self.playback.is_active = auth.is_active;
            }
            SoloistEvent::PlaybackState(snapshot) => {
                let snapshot = *snapshot;
                self.playback = PlaybackState {
                    status: snapshot.status,
                    item: snapshot.item,
                    context: snapshot.context,
                    position: snapshot.position,
                    volume: snapshot.volume,
                    is_active: snapshot.is_active,
                    options: snapshot.options,
                };
            }
            SoloistEvent::TrackChanged { item } => {
                self.playback.item = item.map(|item| *item);
            }
            SoloistEvent::PlaybackChanged { status } => self.playback.status = status,
            SoloistEvent::VolumeChanged { volume } => self.playback.volume = volume,
            SoloistEvent::DeviceChanged {
                is_active,
                device_name,
            } => {
                self.playback.is_active = is_active;
                self.device_name = device_name;
            }
            SoloistEvent::ContextChanged { context } => {
                self.playback.context = context.map(|context| *context);
            }
            SoloistEvent::OptionsChanged { options } => self.playback.options = options,
            SoloistEvent::PositionSync { position } => self.playback.position = position,
            SoloistEvent::QueueChanged(queue) => self.queue = queue.upcoming,
            SoloistEvent::Error { message } => self.status_message = Some(message),
            SoloistEvent::CommandResult { .. } | SoloistEvent::Unknown => {}
        }
    }
}
