use std::collections::{HashMap, HashSet};
use std::sync::Arc;
use tokio::sync::RwLock;
use axum::extract::ws::Message;
use serde_json::json;
use tracing::{info, warn, error};

use crate::models::{
    MessageFrame, UserOnlinePayload, OnlineUsersListPayload,
    ShareRequestIncomingPayload, ShareAcceptedPayload, ShareEndedPayload
};

pub type WsTx = tokio::sync::mpsc::UnboundedSender<Message>;

#[derive(Clone)]
pub struct User {
    pub id: String,
    pub name: String,
    pub profile_image_url: String,
    pub latitude: Option<f64>,
    pub longitude: Option<f64>,
    pub is_online: bool,
}

pub struct AppStateInner {
    pub users: HashMap<String, User>,
    pub connections: HashMap<String, WsTx>,
    // Maps user_id -> partner_id for active shares
    pub active_shares: HashMap<String, String>,
    // Set of (requester_id, target_id)
    pub pending_requests: HashSet<(String, String)>,
}

#[derive(Clone)]
pub struct AppState {
    pub inner: Arc<RwLock<AppStateInner>>,
}

impl AppState {
    pub fn new() -> Self {
        Self {
            inner: Arc::new(RwLock::new(AppStateInner {
                users: HashMap::new(),
                connections: HashMap::new(),
                active_shares: HashMap::new(),
                pending_requests: HashSet::new(),
            })),
        }
    }

    // Helper to send message frame to a single user (in-lock safe)
    fn send_to_user_raw(connections: &HashMap<String, WsTx>, user_id: &str, frame: &MessageFrame) {
        if let Some(tx) = connections.get(user_id) {
            match serde_json::to_string(frame) {
                Ok(json_str) => {
                    if let Err(e) = tx.send(Message::Text(json_str)) {
                        warn!("Failed to send message to user {}: {}", user_id, e);
                    }
                }
                Err(e) => {
                    error!("Failed to serialize message frame: {}", e);
                }
            }
        }
    }

    // Helper to broadcast to all online users except one
    fn broadcast_raw(connections: &HashMap<String, WsTx>, exclude_user_id: Option<&str>, frame: &MessageFrame) {
        let json_str = match serde_json::to_string(frame) {
            Ok(s) => s,
            Err(e) => {
                error!("Failed to serialize broadcast frame: {}", e);
                return;
            }
        };

        for (user_id, tx) in connections.iter() {
            if let Some(exclude) = exclude_user_id {
                if user_id == exclude {
                    continue;
                }
            }
            if let Err(e) = tx.send(Message::Text(json_str.clone())) {
                warn!("Failed to broadcast message to user {}: {}", user_id, e);
            }
        }
    }

    pub async fn register_user(&self, user_id: String, name: String, profile_image_url: String, tx: WsTx) -> User {
        let mut state = self.inner.write().await;
        
        let user = User {
            id: user_id.clone(),
            name,
            profile_image_url,
            latitude: None,
            longitude: None,
            is_online: true,
        };

        state.users.insert(user_id.clone(), user.clone());
        state.connections.insert(user_id.clone(), tx);

        info!("User {} registered and online", user_id);

        // Send auth_success immediately
        let success_frame = MessageFrame {
            r#type: "auth_success".to_string(),
            payload: json!({
                "user_id": user.id,
                "name": user.name,
                "profile_image_url": user.profile_image_url,
            }),
        };
        Self::send_to_user_raw(&state.connections, &user_id, &success_frame);

        user
    }

    pub async fn start_presence(&self, user_id: String, lat: f64, lng: f64) {
        let mut state = self.inner.write().await;
        
        let mut user_to_broadcast = None;
        if let Some(user) = state.users.get_mut(&user_id) {
            user.latitude = Some(lat);
            user.longitude = Some(lng);
            user.is_online = true;
            user_to_broadcast = Some(user.clone());
        }

        if let Some(user) = user_to_broadcast {
            // Broadcast user_online
            let online_frame = MessageFrame {
                r#type: "user_online".to_string(),
                payload: json!(UserOnlinePayload {
                    user_id: user.id.clone(),
                    name: user.name.clone(),
                    profile_image_url: user.profile_image_url.clone(),
                    latitude: user.latitude,
                    longitude: user.longitude,
                }),
            };
            Self::broadcast_raw(&state.connections, Some(&user_id), &online_frame);

            // Send online users list to the user
            let online_users: Vec<UserOnlinePayload> = state.users.values()
                .filter(|u| u.is_online && u.id != user_id)
                .map(|u| UserOnlinePayload {
                    user_id: u.id.clone(),
                    name: u.name.clone(),
                    profile_image_url: u.profile_image_url.clone(),
                    latitude: u.latitude,
                    longitude: u.longitude,
                })
                .collect();

            let list_frame = MessageFrame {
                r#type: "online_users_list".to_string(),
                payload: json!(OnlineUsersListPayload { users: online_users }),
            };
            Self::send_to_user_raw(&state.connections, &user_id, &list_frame);
        }
    }

    pub async fn stop_presence(&self, user_id: String) {
        let mut state = self.inner.write().await;
        
        if let Some(user) = state.users.get_mut(&user_id) {
            user.is_online = false;
        }

        // Broadcast user_offline
        let offline_frame = MessageFrame {
            r#type: "user_offline".to_string(),
            payload: json!({ "user_id": user_id }),
        };
        Self::broadcast_raw(&state.connections, Some(&user_id), &offline_frame);
    }

    pub async fn handle_disconnect(&self, user_id: String) {
        let mut state = self.inner.write().await;
        
        info!("Handling disconnect for user {}", user_id);
        state.connections.remove(&user_id);
        
        if let Some(user) = state.users.get_mut(&user_id) {
            user.is_online = false;
        }

        // Broadcast user_offline
        let offline_frame = MessageFrame {
            r#type: "user_offline".to_string(),
            payload: json!({ "user_id": user_id }),
        };
        Self::broadcast_raw(&state.connections, None, &offline_frame);

        // Clean up pending requests involving this user
        state.pending_requests.retain(|(req, target)| req != &user_id && target != &user_id);

        // Clean up active shares
        if let Some(partner_id) = state.active_shares.remove(&user_id) {
            state.active_shares.remove(&partner_id);

            // Notify partner that share has ended
            let end_frame = MessageFrame {
                r#type: "share_ended".to_string(),
                payload: json!(ShareEndedPayload { partner_id: user_id.clone() }),
            };
            Self::send_to_user_raw(&state.connections, &partner_id, &end_frame);
        }
    }

    pub async fn request_share(&self, requester_id: String, target_id: String) {
        let state = self.inner.read().await;

        // Verify target exists and is online
        if !state.connections.contains_key(&target_id) {
            warn!("Request share failed: target {} is offline or not registered", target_id);
            return;
        }

        let (requester_name, requester_profile_image_url) = match state.users.get(&requester_id) {
            Some(u) => (u.name.clone(), u.profile_image_url.clone()),
            None => return,
        };

        // Write lock to insert request
        drop(state);
        let mut state = self.inner.write().await;
        state.pending_requests.insert((requester_id.clone(), target_id.clone()));

        // Notify target of incoming share request
        let request_frame = MessageFrame {
            r#type: "share_request_incoming".to_string(),
            payload: json!(ShareRequestIncomingPayload {
                requester_id: requester_id.clone(),
                requester_name,
                requester_profile_image_url,
            }),
        };
        Self::send_to_user_raw(&state.connections, &target_id, &request_frame);
        info!("Share request from {} to {} registered", requester_id, target_id);
    }

    pub async fn accept_share(&self, target_id: String, requester_id: String) {
        let mut state = self.inner.write().await;

        if !state.pending_requests.remove(&(requester_id.clone(), target_id.clone())) {
            warn!("Accept share failed: no pending request from {} to {}", requester_id, target_id);
            return;
        }

        // Clean up any existing shares for both users before pairing
        if let Some(prev_partner) = state.active_shares.remove(&requester_id) {
            state.active_shares.remove(&prev_partner);
            let end_frame = MessageFrame {
                r#type: "share_ended".to_string(),
                payload: json!(ShareEndedPayload { partner_id: requester_id.clone() }),
            };
            Self::send_to_user_raw(&state.connections, &prev_partner, &end_frame);
        }
        if let Some(prev_partner) = state.active_shares.remove(&target_id) {
            state.active_shares.remove(&prev_partner);
            let end_frame = MessageFrame {
                r#type: "share_ended".to_string(),
                payload: json!(ShareEndedPayload { partner_id: target_id.clone() }),
            };
            Self::send_to_user_raw(&state.connections, &prev_partner, &end_frame);
        }

        // Establish pairing
        state.active_shares.insert(requester_id.clone(), target_id.clone());
        state.active_shares.insert(target_id.clone(), requester_id.clone());

        let requester = state.users.get(&requester_id).cloned();
        let target = state.users.get(&target_id).cloned();

        if let (Some(r), Some(t)) = (requester, target) {
            // Notify requester
            let req_accepted = MessageFrame {
                r#type: "share_accepted".to_string(),
                payload: json!(ShareAcceptedPayload {
                    partner_id: t.id.clone(),
                    partner_name: t.name.clone(),
                    partner_profile_image_url: t.profile_image_url.clone(),
                }),
            };
            Self::send_to_user_raw(&state.connections, &requester_id, &req_accepted);

            // Notify target
            let target_accepted = MessageFrame {
                r#type: "share_accepted".to_string(),
                payload: json!(ShareAcceptedPayload {
                    partner_id: r.id.clone(),
                    partner_name: r.name.clone(),
                    partner_profile_image_url: r.profile_image_url.clone(),
                }),
            };
            Self::send_to_user_raw(&state.connections, &target_id, &target_accepted);

            info!("Active sharing established between {} and {}", requester_id, target_id);
        }
    }

    pub async fn update_location(&self, user_id: String, lat: f64, lng: f64, timestamp: u64) {
        let mut state = self.inner.write().await;

        if let Some(user) = state.users.get_mut(&user_id) {
            user.latitude = Some(lat);
            user.longitude = Some(lng);
        }

        // Forward stream to partner if in active sharing session
        if let Some(partner_id) = state.active_shares.get(&user_id).cloned() {
            let stream_frame = MessageFrame {
                r#type: "location_stream".to_string(),
                payload: json!({
                    "user_id": user_id,
                    "latitude": lat,
                    "longitude": lng,
                    "timestamp": timestamp,
                }),
            };
            Self::send_to_user_raw(&state.connections, &partner_id, &stream_frame);
        }
    }

    pub async fn end_share(&self, user_id: String, target_id: String) {
        let mut state = self.inner.write().await;

        let removed_req = state.active_shares.remove(&user_id);
        let removed_target = state.active_shares.remove(&target_id);

        if removed_req.is_some() || removed_target.is_some() {
            // Notify both users that share has ended
            let end_frame_a = MessageFrame {
                r#type: "share_ended".to_string(),
                payload: json!(ShareEndedPayload { partner_id: target_id.clone() }),
            };
            Self::send_to_user_raw(&state.connections, &user_id, &end_frame_a);

            let end_frame_b = MessageFrame {
                r#type: "share_ended".to_string(),
                payload: json!(ShareEndedPayload { partner_id: user_id.clone() }),
            };
            Self::send_to_user_raw(&state.connections, &target_id, &end_frame_b);

            info!("Active sharing ended between {} and {}", user_id, target_id);
        }
    }
}
