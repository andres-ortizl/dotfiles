use soloist_tui::soloist::SoloistCommand;

#[test]
fn playback_commands_match_the_soloist_websocket_protocol() {
    assert_eq!(
        SoloistCommand::play_uri("spotify:playlist:abc")
            .to_json()
            .unwrap(),
        r#"{"type":"command","command":"play","uri":"spotify:playlist:abc"}"#
    );
    assert_eq!(
        SoloistCommand::set_volume(55).to_json().unwrap(),
        r#"{"type":"command","command":"set_volume","volume":55}"#
    );
    assert_eq!(
        SoloistCommand::get_queue(80).to_json().unwrap(),
        r#"{"type":"command","command":"get_queue","limit":80}"#
    );
}
