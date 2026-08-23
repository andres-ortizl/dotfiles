use std::path::PathBuf;

use soloist_tui::config::Config;

#[test]
fn missing_web_api_config_starts_in_soloist_only_mode() {
    let missing = PathBuf::from("/tmp/soloist-tui-config-that-does-not-exist.toml");

    let config = Config::load_or_local(&missing).unwrap();

    assert!(!config.spotify_is_configured());
    assert_eq!(config.redirect_uri, "http://127.0.0.1:8888/callback");
    assert!(config.soloist_data_dir.ends_with(".local/share/soloist"));
}
