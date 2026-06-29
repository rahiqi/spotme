use axum::{
    extract::{ws::{Message, WebSocket, WebSocketUpgrade}, State},
    response::IntoResponse,
};
use futures_util::{StreamExt, SinkExt};
use tokio::sync::mpsc;
use uuid::Uuid;
use std::time::Duration;
use tokio::time::timeout;
use tracing::warn;

use crate::state::AppState;
use crate::models::{
    MessageFrame, AuthPayload, StartPresencePayload, ShareRequestPayload,
    AcceptSharePayload, RejectSharePayload, LocationUpdatePayload, EndSharePayload
};

#[derive(serde::Deserialize)]
pub struct LogPayload {
    pub message: String,
    pub stack_trace: Option<String>,
}

pub async fn log_handler(
    axum::Json(payload): axum::Json<LogPayload>,
) -> impl IntoResponse {
    if let Some(ref st) = payload.stack_trace {
        if !st.trim().is_empty() {
            warn!("CLIENT DIAGNOSTIC ERROR: {}\nStack Trace:\n{}", payload.message, st);
        } else {
            warn!("CLIENT DIAGNOSTIC ERROR: {}", payload.message);
        }
    } else {
        warn!("CLIENT DIAGNOSTIC ERROR: {}", payload.message);
    }
    axum::http::StatusCode::OK
}

pub async fn health_handler() -> impl IntoResponse {
    axum::Json(serde_json::json!({
        "status": "healthy",
        "timestamp": chrono::Utc::now().to_rfc3339()
    }))
}

pub async fn ws_handler(
    ws: WebSocketUpgrade,
    State(state): State<AppState>,
) -> impl IntoResponse {
    ws.on_upgrade(|socket| handle_websocket(socket, state))
}

async fn handle_websocket(socket: WebSocket, state: AppState) {
    let (mut ws_sender, mut ws_receiver) = socket.split();

    // Create a channel to buffer outgoing messages
    let (tx, mut rx) = mpsc::unbounded_channel::<Message>();

    // Spawn a writer task to forward messages from the channel to the WebSocket
    let tx_clone = tx.clone();
    let writer_task = tokio::spawn(async move {
        while let Some(msg) = rx.recv().await {
            if let Err(e) = ws_sender.send(msg).await {
                warn!("WebSocket send error: {}", e);
                break;
            }
        }
        // Ensure ws_sender is closed
        let _ = ws_sender.close().await;
    });

    // Wait for the first message (auth) with a timeout of 5 seconds
    let auth_result = timeout(Duration::from_secs(5), ws_receiver.next()).await;

    let user_id = match auth_result {
        Ok(Some(Ok(Message::Text(text)))) => {
            if let Ok(frame) = serde_json::from_str::<MessageFrame>(&text) {
                if frame.r#type == "auth" {
                    if let Ok(auth_payload) = serde_json::from_value::<AuthPayload>(frame.payload) {
                        let uid = auth_payload.user_id.unwrap_or_else(|| Uuid::new_v4().to_string());
                        // Register user with their connection sender
                        state.register_user(uid.clone(), auth_payload.name, auth_payload.profile_image_url, tx_clone).await;
                        Some(uid)
                    } else {
                        None
                    }
                } else {
                    None
                }
            } else {
                None
            }
        }
        _ => None,
    };

    let user_id = match user_id {
        Some(uid) => uid,
        None => {
            warn!("WebSocket authentication failed or timed out. Closing connection.");
            writer_task.abort();
            return;
        }
    };

    // Main read loop
    while let Some(msg_res) = ws_receiver.next().await {
        match msg_res {
            Ok(msg) => {
                match msg {
                    Message::Close(_) => break,
                    Message::Ping(_ping) => {
                        // Axum handles ping/pong automatically, but let's log if needed
                    }
                    Message::Text(_) => {
                        handle_ws_msg(&user_id, msg, &state).await;
                    }
                    _ => {}
                }
            }
            Err(e) => {
                warn!("WebSocket receive error from user {}: {}", user_id, e);
                break;
            }
        }
    }

    // Clean up on disconnect
    state.handle_disconnect(user_id).await;
    writer_task.abort();
}

async fn handle_ws_msg(user_id: &str, msg: Message, state: &AppState) {
    let text = match msg {
        Message::Text(t) => t,
        _ => return,
    };

    let frame: MessageFrame = match serde_json::from_str(&text) {
        Ok(f) => f,
        Err(e) => {
            warn!("Invalid JSON frame from user {}: {}", user_id, e);
            return;
        }
    };

    match frame.r#type.as_str() {
        "start_presence" => {
            if let Ok(payload) = serde_json::from_value::<StartPresencePayload>(frame.payload) {
                state.start_presence(user_id.to_string(), payload.latitude, payload.longitude).await;
            } else {
                warn!("Invalid start_presence payload from user {}", user_id);
            }
        }
        "stop_presence" => {
            state.stop_presence(user_id.to_string()).await;
        }
        "share_request" => {
            if let Ok(payload) = serde_json::from_value::<ShareRequestPayload>(frame.payload) {
                state.request_share(user_id.to_string(), payload.target_id).await;
            } else {
                warn!("Invalid share_request payload from user {}", user_id);
            }
        }
        "accept_share" => {
            if let Ok(payload) = serde_json::from_value::<AcceptSharePayload>(frame.payload) {
                state.accept_share(user_id.to_string(), payload.requester_id).await;
            } else {
                warn!("Invalid accept_share payload from user {}", user_id);
            }
        }
        "reject_share" => {
            if let Ok(payload) = serde_json::from_value::<RejectSharePayload>(frame.payload) {
                state.reject_share(user_id.to_string(), payload.requester_id).await;
            } else {
                warn!("Invalid reject_share payload from user {}", user_id);
            }
        }
        "location_update" => {
            if let Ok(payload) = serde_json::from_value::<LocationUpdatePayload>(frame.payload) {
                state.update_location(user_id.to_string(), payload.latitude, payload.longitude, payload.timestamp).await;
            } else {
                warn!("Invalid location_update payload from user {}", user_id);
            }
        }
        "end_share" => {
            if let Ok(payload) = serde_json::from_value::<EndSharePayload>(frame.payload) {
                state.end_share(user_id.to_string(), payload.target_id).await;
            } else {
                warn!("Invalid end_share payload from user {}", user_id);
            }
        }
        _ => {
            warn!("Unknown message type from user {}: {}", user_id, frame.r#type);
        }
    }
}
