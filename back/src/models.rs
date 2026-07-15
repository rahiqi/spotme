use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct MessageFrame {
    pub r#type: String,
    pub payload: serde_json::Value,
}

// Client -> Server Payloads

#[derive(Debug, Deserialize)]
pub struct AuthPayload {
    pub user_id: Option<String>,
    pub name: String,
    pub profile_image_url: String,
}

#[derive(Debug, Deserialize)]
pub struct StartPresencePayload {
    pub latitude: f64,
    pub longitude: f64,
}

#[derive(Debug, Deserialize)]
pub struct ShareRequestPayload {
    pub target_id: String,
}

#[derive(Debug, Deserialize)]
pub struct AcceptSharePayload {
    pub requester_id: String,
}

#[derive(Debug, Deserialize)]
pub struct RejectSharePayload {
    pub requester_id: String,
}

#[derive(Debug, Deserialize)]
pub struct LocationUpdatePayload {
    pub latitude: f64,
    pub longitude: f64,
    pub timestamp: u64,
}

#[derive(Debug, Deserialize)]
pub struct EndSharePayload {
    pub target_id: String,
}

// Server -> Client Payloads

#[derive(Debug, Serialize, Clone)]
pub struct AuthSuccessPayload {
    pub user_id: String,
    pub name: String,
    pub profile_image_url: String,
}

#[derive(Debug, Serialize, Clone)]
pub struct UserOnlinePayload {
    pub user_id: String,
    pub name: String,
    pub profile_image_url: String,
    pub latitude: Option<f64>,
    pub longitude: Option<f64>,
}

#[derive(Debug, Serialize, Clone)]
pub struct UserOfflinePayload {
    pub user_id: String,
}

#[derive(Debug, Serialize, Clone)]
pub struct OnlineUsersListPayload {
    pub users: Vec<UserOnlinePayload>,
}

#[derive(Debug, Serialize, Clone)]
pub struct ShareRequestIncomingPayload {
    pub requester_id: String,
    pub requester_name: String,
    pub requester_profile_image_url: String,
}

#[derive(Debug, Serialize, Clone)]
pub struct ShareAcceptedPayload {
    pub partner_id: String,
    pub partner_name: String,
    pub partner_profile_image_url: String,
}

#[derive(Debug, Serialize, Clone)]
pub struct LocationStreamPayload {
    pub user_id: String,
    pub latitude: f64,
    pub longitude: f64,
    pub timestamp: u64,
}

#[derive(Debug, Serialize, Clone)]
pub struct ShareEndedPayload {
    pub partner_id: String,
}

// Chat Feature Payloads

#[derive(Debug, Deserialize)]
pub struct SendChatPayload {
    pub receiver_id: String,
    pub content: String,
}

#[derive(Debug, Serialize, Clone)]
pub struct ChatMessagePayload {
    pub id: String,
    pub sender_id: String,
    pub receiver_id: String,
    pub content: String,
    pub timestamp: u64,
}

#[derive(Debug, Deserialize)]
pub struct GetChatHistoryPayload {
    pub partner_id: String,
    pub limit: Option<usize>,
}

#[derive(Debug, Serialize, Clone)]
pub struct ChatHistoryPayload {
    pub partner_id: String,
    pub messages: Vec<ChatMessagePayload>,
}
