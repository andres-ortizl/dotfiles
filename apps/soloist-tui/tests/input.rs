use crossterm::event::{KeyCode, KeyEvent, KeyModifiers};
use soloist_tui::{
    app::{AppState, InputMode, Tab},
    input::{Action, SpotifyRequest, handle_key},
    soloist::{PlaybackStatus, SoloistCommand},
};

#[test]
fn search_mode_collects_text_and_submits_a_request() {
    let mut app = AppState::default();
    assert_eq!(handle_key(&mut app, key('/'), 0), vec![]);
    for character in "radiohead".chars() {
        handle_key(&mut app, key(character), 0);
    }

    let actions = handle_key(
        &mut app,
        KeyEvent::new(KeyCode::Enter, KeyModifiers::NONE),
        0,
    );

    assert_eq!(app.active_tab, Tab::Search);
    assert_eq!(app.input_mode, InputMode::Normal);
    assert_eq!(
        actions,
        vec![Action::Spotify(SpotifyRequest::Search("radiohead".into()))]
    );
}

#[test]
fn playback_key_uses_current_player_state() {
    let mut app = AppState::default();
    app.playback.status = PlaybackStatus::Playing;

    assert_eq!(
        handle_key(
            &mut app,
            KeyEvent::new(KeyCode::Char(' '), KeyModifiers::NONE),
            0
        ),
        vec![Action::Soloist(SoloistCommand::pause())]
    );
}

fn key(character: char) -> KeyEvent {
    KeyEvent::new(KeyCode::Char(character), KeyModifiers::NONE)
}
