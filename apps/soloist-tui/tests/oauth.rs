use soloist_tui::spotify::authorization_request;

#[test]
fn authorization_request_uses_pkce_and_minimal_scoped_credentials() {
    let (url, pending) =
        authorization_request("client-123", "http://127.0.0.1:8888/callback").unwrap();
    let query = url
        .query_pairs()
        .collect::<std::collections::HashMap<_, _>>();

    assert_eq!(query.get("client_id").unwrap(), "client-123");
    assert_eq!(query.get("code_challenge_method").unwrap(), "S256");
    assert!(query.get("code_challenge").unwrap().len() >= 43);
    assert_eq!(
        query.get("redirect_uri").unwrap(),
        "http://127.0.0.1:8888/callback"
    );
    assert!(query.get("scope").unwrap().contains("user-library-read"));
    assert!(!url.as_str().contains("client_secret"));
    assert!(!pending.csrf_state().is_empty());
}
