use soloist_tui::spotify::{MediaKind, parse_page};

#[test]
fn saved_library_wrappers_are_normalized() {
    let items = parse_page(
        r#"{"items":[{"added_at":"2026-01-01","track":{"uri":"spotify:track:1","name":"Reckoner","artists":[{"name":"Radiohead"}],"album":{"images":[]}}}]}"#,
        MediaKind::Track,
    )
    .unwrap();

    assert_eq!(items.len(), 1);
    assert_eq!(items[0].name, "Reckoner");
    assert_eq!(items[0].subtitle, "Radiohead");
}

#[test]
fn playlist_item_wrappers_accept_tracks_and_episodes() {
    let items = soloist_tui::spotify::parse_mixed_page(
        r#"{"items":[
            {"item":{"type":"track","uri":"spotify:track:1","name":"Lotus Flower","artists":[{"name":"Radiohead"}],"album":{"images":[]}}},
            {"item":{"type":"episode","uri":"spotify:episode:2","name":"The Rust Episode","duration_ms":120000,"show":{"publisher":"Syntax"},"images":[]}}
        ]}"#,
    )
    .unwrap();

    assert_eq!(items.len(), 2);
    assert_eq!(items[0].kind, MediaKind::Track);
    assert_eq!(items[1].kind, MediaKind::Episode);
    assert_eq!(items[1].subtitle, "Syntax");
}
