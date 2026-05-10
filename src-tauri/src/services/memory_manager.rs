use crate::models::{
    chat::{ChatMessage, MessageRole},
    memory::{EmotionalMemory, LongTermMemory, MemoryCategory, MemoryEntry, SessionSummary},
};
use chrono::Utc;
use regex::Regex;

pub struct MemoryManager {
    pub enabled: bool,
    pub long_term: LongTermMemory,
    session_topics: Vec<String>,
    session_summary: String,
    session_message_count: usize,
    extraction_interval: usize,
}

impl MemoryManager {
    pub fn new(memory: LongTermMemory) -> Self {
        Self {
            enabled: true,
            long_term: memory,
            session_topics: Vec::new(),
            session_summary: String::new(),
            session_message_count: 0,
            extraction_interval: 6,
        }
    }

    /// 生成注入到 system prompt 中的记忆上下文
    pub fn build_memory_context(&self) -> String {
        if !self.enabled {
            return String::new();
        }
        let mut parts: Vec<String> = Vec::new();

        if !self.long_term.user_profile.is_empty() {
            let profile: Vec<String> = self
                .long_term
                .user_profile
                .iter()
                .map(|(k, v)| format!("{k}: {v}"))
                .collect();
            parts.push(format!("【主人信息】{}", profile.join("、")));
        }

        let facts: Vec<_> = self.long_term.facts.iter().rev().take(15).collect();
        if !facts.is_empty() {
            let s: Vec<String> = facts.iter().map(|f| format!("- {}", f.content)).collect();
            parts.push(format!("【记住的事情】\n{}", s.join("\n")));
        }

        let emotions: Vec<_> = self
            .long_term
            .emotional_memories
            .iter()
            .rev()
            .take(5)
            .collect();
        if !emotions.is_empty() {
            let s: Vec<String> = emotions
                .iter()
                .map(|e| format!("- {}（{}）", e.content, e.emotion))
                .collect();
            parts.push(format!("【情感记忆】\n{}", s.join("\n")));
        }

        let sessions: Vec<_> = self
            .long_term
            .session_summaries
            .iter()
            .rev()
            .take(3)
            .collect();
        if !sessions.is_empty() {
            let s: Vec<String> = sessions
                .iter()
                .map(|s| {
                    let d = s.date.format("%-m月%-d日").to_string();
                    format!("- [{d}] {}", s.summary)
                })
                .collect();
            parts.push(format!("【最近的聊天记忆】\n{}", s.join("\n")));
        }

        if !self.session_summary.is_empty() {
            parts.push(format!("【本次聊天概要】{}", self.session_summary));
        }
        if !self.session_topics.is_empty() {
            parts.push(format!(
                "【本次聊过的话题】{}",
                self.session_topics.join("、")
            ));
        }

        if parts.is_empty() {
            return String::new();
        }

        format!(
            "\n\n--- 小黑的记忆 ---\n{}\n--- 记忆结束 ---\n\
            （请自然地运用这些记忆，不要直接说'根据我的记忆'，而是像真的记得一样自然提起。）",
            parts.join("\n\n")
        )
    }

    pub fn process_conversation(&mut self, messages: &[ChatMessage]) {
        if !self.enabled {
            return;
        }
        self.session_message_count += 1;

        let recent_user: Vec<_> = messages
            .iter()
            .rev()
            .take(4)
            .filter(|m| matches!(m.role, MessageRole::User))
            .collect();

        for msg in recent_user {
            self.extract_from_text(&msg.content, msg.timestamp);
        }

        if self.session_message_count % self.extraction_interval == 0 {
            self.update_session_summary(messages);
        }
    }

    pub fn end_session(&mut self, messages: &[ChatMessage]) {
        if !self.enabled || messages.len() < 2 {
            return;
        }
        self.update_session_summary(messages);
        if !self.session_summary.is_empty() {
            self.long_term.session_summaries.push(SessionSummary {
                date: Utc::now(),
                summary: self.session_summary.clone(),
                topics: self.session_topics.clone(),
                message_count: messages.len(),
            });
            if self.long_term.session_summaries.len() > 20 {
                self.long_term
                    .session_summaries
                    .drain(..self.long_term.session_summaries.len() - 20);
            }
        }
        self.session_topics.clear();
        self.session_summary.clear();
        self.session_message_count = 0;
    }

    pub fn clear_all(&mut self) {
        self.long_term = LongTermMemory::default();
        self.session_topics.clear();
        self.session_summary.clear();
        self.session_message_count = 0;
    }

    fn extract_from_text(&mut self, text: &str, timestamp: chrono::DateTime<Utc>) {
        let lowered = text.to_lowercase();

        // 名字
        for pattern in &["我叫", "我的名字是", "叫我", "称呼我"] {
            if let Some(idx) = text.find(pattern) {
                let after = &text[idx + pattern.len()..];
                let name = first_segment(after, 10);
                if !name.is_empty() && name.chars().count() <= 8 {
                    self.update_profile("称呼", &name);
                }
            }
        }

        // 年龄
        if let Ok(re) = Regex::new(r"我(今年)?\s*\d{1,3}\s*岁") {
            if let Some(m) = re.find(text) {
                self.update_profile("年龄", m.as_str());
            }
        }

        // 职业
        for pattern in &["我是做", "我的工作是", "我的职业是", "我是一个", "我是一名"]
        {
            if let Some(idx) = text.find(pattern) {
                let after = &text[idx + pattern.len()..];
                let job = first_segment(after, 15);
                if !job.is_empty() {
                    self.update_profile("职业", &job);
                }
            }
        }

        // 爱好
        for pattern in &["我喜欢", "我爱", "我最喜欢", "我的爱好是"] {
            if let Some(idx) = text.find(pattern) {
                let after = &text[idx + pattern.len()..];
                let hobby = first_segment(after, 20);
                if !hobby.is_empty() {
                    self.add_fact(
                        &format!("主人喜欢{hobby}"),
                        MemoryCategory::Preference,
                        timestamp,
                    );
                }
            }
        }

        // 事实
        let fact_patterns = ["我有一", "我养了", "我家", "我今天", "我明天", "我昨天"];
        for pattern in &fact_patterns {
            if text.contains(pattern) {
                let fact: String = text.chars().take(40).collect();
                self.add_fact(&fact, MemoryCategory::Fact, timestamp);
                break;
            }
        }

        // 情感
        let emotion_map: &[(&[&str], &str)] = &[
            (&["开心", "高兴", "太好了", "哈哈", "好棒"], "开心"),
            (&["难过", "伤心", "不开心", "郁闷", "心情不好"], "难过"),
            (&["生气", "气死", "讨厌", "烦死"], "生气"),
            (&["累", "好累", "疲惫", "困了", "好困"], "疲惫"),
            (&["无聊", "好无聊", "没意思"], "无聊"),
            (&["害怕", "好怕", "紧张", "焦虑"], "焦虑"),
        ];
        for (patterns, emotion) in emotion_map {
            if patterns.iter().any(|p| lowered.contains(p)) {
                let content: String = text.chars().take(30).collect();
                self.add_emotional_memory(&content, emotion, timestamp);
                break;
            }
        }

        // 话题
        for keyword in &["聊聊", "说说", "讲讲", "告诉我", "什么是", "怎么"] {
            if let Some(idx) = text.find(keyword) {
                let after = &text[idx + keyword.len()..];
                let topic = first_segment(after, 10);
                if !topic.is_empty() && !self.session_topics.contains(&topic) {
                    self.session_topics.push(topic);
                    if self.session_topics.len() > 10 {
                        self.session_topics.remove(0);
                    }
                }
            }
        }
    }

    fn update_session_summary(&mut self, messages: &[ChatMessage]) {
        let user_msgs: Vec<_> = messages
            .iter()
            .filter(|m| matches!(m.role, MessageRole::User))
            .collect();
        if user_msgs.is_empty() {
            return;
        }
        let topics: Vec<String> = user_msgs
            .iter()
            .rev()
            .take(6)
            .map(|m| {
                let chars: Vec<char> = m.content.chars().collect();
                if chars.len() <= 15 {
                    m.content.clone()
                } else {
                    format!("{}...", chars[..15].iter().collect::<String>())
                }
            })
            .collect();
        self.session_summary = format!("聊了：{}", topics.join("；"));
    }

    fn update_profile(&mut self, key: &str, value: &str) {
        let cleaned = value
            .trim()
            .replace('，', "")
            .replace('。', "")
            .replace('的', "");
        if cleaned.is_empty() || cleaned.chars().count() > 20 {
            return;
        }
        if self.long_term.user_profile.get(key).map(|v| v.as_str()) != Some(&cleaned) {
            self.long_term.user_profile.insert(key.into(), cleaned);
        }
    }

    fn add_fact(
        &mut self,
        content: &str,
        category: MemoryCategory,
        timestamp: chrono::DateTime<Utc>,
    ) {
        let is_dup = self.long_term.facts.iter().any(|f| {
            f.content == content
                || (f.content.len() > 5 && content.contains(&f.content))
                || (content.len() > 5 && f.content.contains(content))
        });
        if is_dup {
            return;
        }
        self.long_term.facts.push(MemoryEntry {
            content: content.into(),
            category,
            timestamp,
        });
        if self.long_term.facts.len() > 50 {
            self.long_term.facts.remove(0);
        }
    }

    fn add_emotional_memory(
        &mut self,
        content: &str,
        emotion: &str,
        timestamp: chrono::DateTime<Utc>,
    ) {
        self.long_term.emotional_memories.push(EmotionalMemory {
            content: content.into(),
            emotion: emotion.into(),
            timestamp,
        });
        if self.long_term.emotional_memories.len() > 20 {
            self.long_term.emotional_memories.remove(0);
        }
    }
}

fn first_segment(text: &str, max_chars: usize) -> String {
    let trimmed = text.trim();
    let delimiters: &[char] = &[
        '，', '。', '！', '？', '、', '；', '：', '\n', ',', '.', '!', '?', ';', ':', ' ',
    ];
    let segment = trimmed.split(delimiters).next().unwrap_or("").trim();
    segment.chars().take(max_chars).collect()
}
