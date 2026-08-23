use futures_util::{SinkExt, StreamExt};
use soloist_tui::soloist::{SoloistCommand, SoloistEvent, SoloistNotification, run_connection};
use tokio::{net::TcpListener, sync::mpsc};
use tokio_tungstenite::{accept_async, tungstenite::Message};
use url::Url;

#[tokio::test]
async fn websocket_connection_forwards_events_and_commands() {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let address = listener.local_addr().unwrap();
    let server = tokio::spawn(async move {
        let (stream, _) = listener.accept().await.unwrap();
        let mut socket = accept_async(stream).await.unwrap();
        socket
            .send(Message::Text(
                r#"{"type":"auth_state","logged_in":true,"is_active":true,"device_name":"Test player"}"#.into(),
            ))
            .await
            .unwrap();
        socket.next().await.unwrap().unwrap().into_text().unwrap()
    });

    let (commands_tx, commands_rx) = mpsc::channel(4);
    let (notifications_tx, mut notifications_rx) = mpsc::channel(4);
    let endpoint = Url::parse(&format!("ws://{address}")).unwrap();
    let connection = tokio::spawn(async move {
        let mut commands_rx = commands_rx;
        run_connection(endpoint, &mut commands_rx, notifications_tx).await
    });

    assert!(matches!(
        notifications_rx.recv().await.unwrap(),
        SoloistNotification::Connected
    ));
    assert!(matches!(
        notifications_rx.recv().await.unwrap(),
        SoloistNotification::Event(event) if matches!(*event, SoloistEvent::AuthState(_))
    ));

    commands_tx.send(SoloistCommand::pause()).await.unwrap();
    assert_eq!(
        server.await.unwrap(),
        r#"{"type":"command","command":"pause"}"#
    );
    connection.abort();
}
