use std::{
    fs,
    time::{SystemTime, UNIX_EPOCH},
};

use soloist_tui::soloist::discover_endpoint;

#[tokio::test]
async fn discovers_the_runtime_websocket_endpoint_from_soloist_data() {
    let unique = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let data_dir = std::env::temp_dir().join(format!("soloist-tui-test-{unique}"));
    fs::create_dir_all(&data_dir).unwrap();
    fs::write(data_dir.join("ws.addr"), "127.0.0.1\n").unwrap();
    fs::write(data_dir.join("ws.port"), "49152\n").unwrap();

    let endpoint = discover_endpoint(&data_dir).await.unwrap();

    assert_eq!(endpoint.as_str(), "ws://127.0.0.1:49152/");
    fs::remove_dir_all(data_dir).unwrap();
}
