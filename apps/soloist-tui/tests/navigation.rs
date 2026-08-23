use soloist_tui::{
    app::{AppState, Tab},
    spotify::{MediaItem, MediaKind},
};

#[test]
fn selection_tracks_the_active_collection_and_stays_in_bounds() {
    let mut app = AppState::default();
    app.active_tab = Tab::Search;
    app.search_results = vec![media("spotify:track:1"), media("spotify:track:2")];

    app.move_selection(1);
    app.move_selection(1);

    assert_eq!(app.selected_uri(), Some("spotify:track:2"));
    app.move_selection(-1);
    assert_eq!(app.selected_uri(), Some("spotify:track:1"));
}

fn media(uri: &str) -> MediaItem {
    MediaItem {
        uri: uri.into(),
        name: uri.into(),
        subtitle: "Radiohead".into(),
        kind: MediaKind::Track,
        image_url: None,
        duration_ms: None,
    }
}
