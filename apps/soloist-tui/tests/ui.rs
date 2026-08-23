use ratatui::{Terminal, backend::TestBackend, style::Color};
use soloist_tui::{
    app::{AppState, ConnectionStatus, InputMode, Tab},
    soloist::SoloistEvent,
    spotify::{MediaItem, MediaKind},
    ui,
};

#[test]
fn now_playing_screen_renders_player_and_navigation() {
    let mut app = AppState::default();
    app.set_soloist_connection(ConnectionStatus::Connected);
    app.apply_soloist_event(SoloistEvent::from_json(
        r#"{"type":"playback_state","status":"playing","item":{"uri":"spotify:track:1","entity_type":"track","decorations":{"identity":{"name":"Jigsaw Falling Into Place"},"creators":[{"entity":{"entity_type":"artist","decorations":{"identity":{"name":"Radiohead"}}}}],"playback":{"duration_ms":248000}}},"context":null,"position":{"position_ms":62000,"timestamp_ms":100000,"speed":1.0},"volume":70,"is_active":true,"options":{"shuffle":false,"repeat":"off","playback_speed":1.0}}"#,
    ).unwrap());

    let mut terminal = Terminal::new(TestBackend::new(100, 30)).unwrap();
    terminal
        .draw(|frame| ui::render(frame, &app, 100000))
        .unwrap();
    let content = terminal
        .backend()
        .buffer()
        .content()
        .iter()
        .map(|cell| cell.symbol())
        .collect::<String>();

    assert!(content.contains("SOLOIST"));
    assert!(content.contains("Jigsaw Falling Into Place"));
    assert!(content.contains("Radiohead"));
    assert!(content.contains("Now Playing"));
    assert!(content.contains("Search"));
}

#[test]
fn player_uses_the_desktop_catppuccin_mocha_background() {
    let app = AppState::default();
    let mut terminal = Terminal::new(TestBackend::new(100, 30)).unwrap();
    terminal.draw(|frame| ui::render(frame, &app, 0)).unwrap();

    assert_eq!(
        terminal.backend().buffer()[(0, 3)].bg,
        Color::Rgb(30, 30, 46)
    );
}

#[test]
fn search_screen_renders_query_and_results() {
    let mut app = AppState::default();
    app.active_tab = Tab::Search;
    app.input_mode = InputMode::Search;
    app.search_query = "radiohead".into();
    app.search_results = vec![MediaItem {
        uri: "spotify:track:1".into(),
        name: "Reckoner".into(),
        subtitle: "Radiohead".into(),
        kind: MediaKind::Track,
        image_url: None,
        duration_ms: Some(290000),
    }];

    let mut terminal = Terminal::new(TestBackend::new(100, 30)).unwrap();
    terminal.draw(|frame| ui::render(frame, &app, 0)).unwrap();
    let content = terminal
        .backend()
        .buffer()
        .content()
        .iter()
        .map(|cell| cell.symbol())
        .collect::<String>();

    assert!(content.contains("Search: radiohead"));
    assert!(content.contains("Reckoner"));
    assert!(content.contains("Radiohead"));
}

#[test]
fn every_view_includes_a_grouped_controls_legend() {
    let app = AppState::default();
    let mut terminal = Terminal::new(TestBackend::new(120, 35)).unwrap();
    terminal.draw(|frame| ui::render(frame, &app, 0)).unwrap();
    let content = terminal
        .backend()
        .buffer()
        .content()
        .iter()
        .map(|cell| cell.symbol())
        .collect::<String>();

    assert!(content.contains("CONTROLS"));
    assert!(content.contains("Play / Pause"));
    assert!(content.contains("Save / Remove"));
    assert!(content.contains("1-5"));
}

#[test]
fn footer_explains_when_web_api_features_are_unavailable() {
    let app = AppState::default();
    let mut terminal = Terminal::new(TestBackend::new(100, 30)).unwrap();
    terminal.draw(|frame| ui::render(frame, &app, 0)).unwrap();
    let content = terminal
        .backend()
        .buffer()
        .content()
        .iter()
        .map(|cell| cell.symbol())
        .collect::<String>();

    assert!(content.contains("Soloist-only mode"));
}
