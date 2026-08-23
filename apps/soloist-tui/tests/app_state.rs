use soloist_tui::{
    app::{AppState, ConnectionStatus},
    soloist::{PlaybackStatus, SoloistEvent},
};

#[test]
fn app_state_applies_snapshots_and_incremental_events() {
    let mut app = AppState::default();
    app.set_soloist_connection(ConnectionStatus::Connected);

    app.apply_soloist_event(
        SoloistEvent::from_json(
            r#"{
                "type":"playback_state",
                "status":"playing",
                "item":{"uri":"spotify:track:1","entity_type":"track","decorations":{"identity":{"name":"Everything In Its Right Place"},"playback":{"duration_ms":251000}}},
                "context":null,
                "position":{"position_ms":10000,"timestamp_ms":100000,"speed":1.0},
                "volume":40,
                "is_active":true,
                "options":{"shuffle":false,"repeat":"off","playback_speed":1.0}
            }"#,
        )
        .unwrap(),
    );
    app.apply_soloist_event(
        SoloistEvent::from_json(r#"{"type":"volume_changed","volume":72}"#).unwrap(),
    );
    app.apply_soloist_event(
        SoloistEvent::from_json(r#"{"type":"playback_changed","status":"paused"}"#).unwrap(),
    );

    assert_eq!(app.playback.status, PlaybackStatus::Paused);
    assert_eq!(
        app.playback.item.as_ref().unwrap().name(),
        "Everything In Its Right Place"
    );
    assert_eq!(app.playback.volume, 72);
    assert_eq!(app.playback.position_at(105000), 10000);
}
