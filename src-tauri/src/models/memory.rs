use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct LongTermMemory {
    pub user_profile: HashMap<String, String>,
    pub facts: Vec<MemoryEntry>,
    pub emotional_memories: Vec<EmotionalMemory>,
    pub session_summaries: Vec<SessionSummary>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MemoryEntry {
    pub content: String,
    pub category: MemoryCategory,
    pub timestamp: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum MemoryCategory {
    Fact,
    Preference,
    Event,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EmotionalMemory {
    pub content: String,
    pub emotion: String,
    pub timestamp: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionSummary {
    pub date: DateTime<Utc>,
    pub summary: String,
    pub topics: Vec<String>,
    pub message_count: usize,
}
