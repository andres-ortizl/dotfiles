use soloist_tui::spotify::{MediaKind, SpotifyClient};
use tokio::{
    io::{AsyncReadExt, AsyncWriteExt},
    net::TcpListener,
};
use url::Url;

#[tokio::test]
async fn search_uses_bearer_auth_and_returns_normalized_results() {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let address = listener.local_addr().unwrap();
    let server = tokio::spawn(async move {
        let (mut stream, _) = listener.accept().await.unwrap();
        let mut request = vec![0; 8192];
        let size = stream.read(&mut request).await.unwrap();
        let request = String::from_utf8_lossy(&request[..size]);
        assert!(request.starts_with("GET /search?"));
        assert!(request.contains("q=radiohead+live"));
        assert!(
            request
                .to_ascii_lowercase()
                .contains("authorization: bearer access-token")
        );

        let body = r#"{"tracks":{"items":[{"uri":"spotify:track:1","name":"Idioteque","artists":[{"name":"Radiohead"}],"album":{"images":[]}}]}}"#;
        let response = format!(
            "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
            body.len(),
            body
        );
        stream.write_all(response.as_bytes()).await.unwrap();
    });

    let client = SpotifyClient::with_base_url(
        "access-token",
        Url::parse(&format!("http://{address}/")).unwrap(),
    );
    let results = client.search("radiohead live").await.unwrap();

    assert_eq!(results.len(), 1);
    assert_eq!(results[0].kind, MediaKind::Track);
    assert_eq!(results[0].name, "Idioteque");
    server.await.unwrap();
}
