use std::{
    fs,
    time::{SystemTime, UNIX_EPOCH},
};

use soloist_tui::config::Config;

#[test]
fn minimal_config_uses_safe_local_defaults() {
    let unique = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let dir = std::env::temp_dir().join(format!("soloist-tui-config-{unique}"));
    fs::create_dir_all(&dir).unwrap();
    let path = dir.join("config.toml");
    fs::write(&path, "spotify_client_id = \"client-123\"\n").unwrap();

    let config = Config::load(&path).unwrap();

    assert_eq!(config.spotify_client_id, "client-123");
    assert_eq!(config.redirect_uri, "http://127.0.0.1:8888/callback");
    assert!(config.soloist_data_dir.ends_with(".local/share/soloist"));
    fs::remove_dir_all(dir).unwrap();
}
