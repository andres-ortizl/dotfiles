use soloist_tui::soloist::{PlaybackStatus, SoloistEvent};

#[test]
fn playback_snapshot_exposes_now_playing_metadata() {
    let event = SoloistEvent::from_json(
        r#"{
            "type": "playback_state",
            "status": "playing",
            "item": {
                "uri": "spotify:track:123",
                "entity_type": "track",
                "decorations": {
                    "identity": { "name": "Paranoid Android" },
                    "parent": { "entity": { "uri": "spotify:album:456", "entity_type": "album", "decorations": { "identity": { "name": "OK Computer" } } } },
                    "creators": [{ "entity": { "uri": "spotify:artist:789", "entity_type": "artist", "decorations": { "identity": { "name": "Radiohead" } } } }],
                    "playback": { "duration_ms": 386000, "content_ratings": [] }
                }
            },
            "context": { "uri": "spotify:album:456", "entity_type": "album", "decorations": {} },
            "position": { "position_ms": 42000, "timestamp_ms": 1000, "speed": 1.0 },
            "volume": 65,
            "is_active": true,
            "options": { "shuffle": false, "repeat": "off", "playback_speed": 1.0, "modes": {} },
            "available_actions": { "pause": {} }
        }"#,
    )
    .expect("valid Soloist event");

    let SoloistEvent::PlaybackState(snapshot) = event else {
        panic!("expected playback snapshot");
    };

    assert_eq!(snapshot.status, PlaybackStatus::Playing);
    assert_eq!(snapshot.item.as_ref().unwrap().name(), "Paranoid Android");
    assert_eq!(snapshot.item.as_ref().unwrap().creators(), ["Radiohead"]);
    assert_eq!(snapshot.item.as_ref().unwrap().duration_ms(), Some(386000));
    assert_eq!(snapshot.volume, 65);
}
