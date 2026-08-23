use std::{
    fs,
    os::unix::fs::PermissionsExt,
    time::{SystemTime, UNIX_EPOCH},
};

use soloist_tui::spotify::{StoredToken, TokenStore};

#[test]
fn token_store_round_trips_credentials_with_private_permissions() {
    let unique = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let dir = std::env::temp_dir().join(format!("soloist-tui-token-{unique}"));
    let path = dir.join("token.json");
    let store = TokenStore::new(path.clone());
    let token = StoredToken {
        access_token: "access".into(),
        refresh_token: Some("refresh".into()),
        expires_at: 2_000_000_000,
    };

    store.save(&token).unwrap();

    assert_eq!(store.load().unwrap(), Some(token));
    assert_eq!(
        fs::metadata(&path).unwrap().permissions().mode() & 0o777,
        0o600
    );
    fs::remove_dir_all(dir).unwrap();
}
