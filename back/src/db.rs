use rusqlite::{params, Connection, Result};
use std::sync::{Arc, Mutex};
use tracing::{info, error};
use serde::{Serialize, Deserialize};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ChatMessage {
    pub id: String,
    pub sender_id: String,
    pub receiver_id: String,
    pub content: String,
    pub timestamp: u64,
}

#[derive(Clone)]
pub struct Db {
    conn: Arc<Mutex<Connection>>,
}

impl Db {
    pub fn new(path: &str) -> Self {
        // Ensure any parent directory exists (e.g. data/ if it doesn't already exist)
        if let Some(parent) = std::path::Path::new(path).parent() {
            if !parent.exists() {
                std::fs::create_dir_all(parent).ok();
            }
        }

        let conn = Connection::open(path).expect("Failed to open database");
        
        conn.execute(
            "CREATE TABLE IF NOT EXISTS chat_messages (
                id TEXT PRIMARY KEY,
                sender_id TEXT NOT NULL,
                receiver_id TEXT NOT NULL,
                content TEXT NOT NULL,
                timestamp INTEGER NOT NULL
            )",
            [],
        ).expect("Failed to create chat_messages table");

        // Create indexes to optimize history fetches between two paired users
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_chat_messages_participants 
             ON chat_messages(sender_id, receiver_id)",
            [],
        ).ok();

        info!("SQLite Database initialized successfully at {}", path);

        Self {
            conn: Arc::new(Mutex::new(conn)),
        }
    }

    pub fn save_message(&self, msg: ChatMessage) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "INSERT INTO chat_messages (id, sender_id, receiver_id, content, timestamp)
             VALUES (?1, ?2, ?3, ?4, ?5)",
            params![msg.id, msg.sender_id, msg.receiver_id, msg.content, msg.timestamp],
        )?;
        Ok(())
    }

    pub fn get_chat_history(&self, user_a: &str, user_b: &str, limit: usize) -> Result<Vec<ChatMessage>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, sender_id, receiver_id, content, timestamp 
             FROM chat_messages 
             WHERE (sender_id = ?1 AND receiver_id = ?2) 
                OR (sender_id = ?2 AND receiver_id = ?1)
             ORDER BY timestamp DESC
             LIMIT ?3"
        )?;
        
        let rows = stmt.query_map(params![user_a, user_b, limit], |row| {
            Ok(ChatMessage {
                id: row.get(0)?,
                sender_id: row.get(1)?,
                receiver_id: row.get(2)?,
                content: row.get(3)?,
                timestamp: row.get(4)?,
            })
        })?;

        let mut messages = Vec::new();
        for row in rows {
            messages.push(row?);
        }
        
        // Reverse so that the client receives messages in chronological order (oldest first)
        messages.reverse();
        Ok(messages)
    }
}
