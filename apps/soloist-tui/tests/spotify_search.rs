use soloist_tui::spotify::{MediaKind, parse_search_results};

#[test]
fn search_results_are_normalized_for_the_tui() {
    let results = parse_search_results(
        r#"{
            "tracks": {"items": [{
                "uri":"spotify:track:1",
                "name":"Weird Fishes/Arpeggi",
                "duration_ms":305000,
                "artists":[{"name":"Radiohead"}],
                "album":{"images":[{"url":"https://img/large"},{"url":"https://img/small"}]}
            }]},
            "playlists": {"items": [{
                "uri":"spotify:playlist:2",
                "name":"Night Coding",
                "owner":{"display_name":"Andrés"},
                "images":[{"url":"https://img/playlist"}]
            }]}
        }"#,
    )
    .unwrap();

    assert_eq!(results.len(), 2);
    assert_eq!(results[0].kind, MediaKind::Track);
    assert_eq!(results[0].subtitle, "Radiohead");
    assert_eq!(results[0].image_url.as_deref(), Some("https://img/small"));
    assert_eq!(results[1].kind, MediaKind::Playlist);
    assert_eq!(results[1].subtitle, "Andrés");
}
