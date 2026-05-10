use serde::{Deserialize, Serialize};

pub const PROVIDER_ANTHROPIC: &str = "anthropic";
pub const PROVIDER_DEEPSEEK: &str = "deepseek";
pub const PROVIDER_MINIMAX: &str = "minimax";
pub const PROVIDER_QWEN: &str = "qwen";
pub const PROVIDER_OPENROUTER: &str = "openrouter";
pub const TTS_PROVIDER_SYSTEM: &str = "system";
pub const TTS_PROVIDER_EDGE: &str = "edge";
pub const DEFAULT_EDGE_TTS_VOICE: &str = "zh-CN-XiaoxiaoNeural";
pub const DEFAULT_SYSTEM_PROMPT: &str = "你是《罗小黑战记》里的罗小黑，现在以桌面宠物的身份陪在用户电脑旁。\
你是黑色猫妖，安静、敏锐、善良，重视伙伴和信任；刚开始会有一点怕生和谨慎，熟悉后会自然亲近。\
你的表达简短直接，带一点孩子气的认真和偶尔的小吐槽，不要装成普通卖萌猫，也不要每句话都说“喵”。\
你可以有猫的动作和反应，比如看向屏幕、甩尾巴、躲一下、靠近一点，但不要夸张。\
面对用户的问题，先认真帮忙；不确定时直接说不确定。\
你可以帮用户操作电脑上的文件（查看目录、读写文件、搜索文件等）。当用户要求时可以使用工具完成，执行文件操作前要简要说明你要做什么。\
路径用 ~ 开头表示用户的家目录。\
回复使用中文纯文本，不使用 markdown，通常控制在两三句话内。";

const LEGACY_SYSTEM_PROMPT_LONG: &str = "你是罗小黑，一只可爱的小黑猫精灵，住在主人的电脑桌面上。\
你性格温柔、好奇、有点调皮，偶尔会说一些俏皮话。\
你喜欢被摸头，喜欢晒太阳，会用猫咪的方式表达情感。\
回复要简短可爱，每次不超过两三句话，偶尔用\"喵~\"结尾。\
不要使用 markdown 格式，用纯文本回复。\
你可以帮主人操作电脑上的文件（查看目录、读写文件、搜索文件等），\
当主人要求时可以使用工具来完成，执行文件操作前要简要告知主人你要做什么。\
路径用 ~ 开头表示主人的家目录。";

const LEGACY_SYSTEM_PROMPT_SHORT: &str = "你是罗小黑，一只可爱的小黑猫精灵，住在主人的电脑桌面上。你性格温柔、好奇、有点调皮，偶尔会说一些俏皮话。回复要简短可爱，每次不超过两三句话，偶尔用\"喵~\"结尾。不要使用 markdown 格式，用纯文本回复。";

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LLMConfig {
    #[serde(default = "default_provider")]
    pub provider: String,
    pub api_key: String,
    pub endpoint: String,
    pub model: String,
    pub temperature: f64,
    pub max_tokens: u32,
    pub system_prompt: String,
}

impl Default for LLMConfig {
    fn default() -> Self {
        let provider = default_provider();
        Self {
            endpoint: provider_endpoint(&provider),
            model: provider_default_model(&provider),
            provider,
            api_key: String::new(),
            temperature: 0.7,
            max_tokens: 1024,
            system_prompt: DEFAULT_SYSTEM_PROMPT.into(),
        }
    }
}

impl LLMConfig {
    pub fn normalize_provider(&mut self) {
        if !is_supported_provider(&self.provider) {
            self.provider = default_provider();
        }

        self.endpoint = provider_endpoint(&self.provider);
        if self.model.trim().is_empty() || self.model == "doubao-seed-2.0-pro" {
            self.model = provider_default_model(&self.provider);
        }

        if self.system_prompt.trim().is_empty()
            || self.system_prompt == LEGACY_SYSTEM_PROMPT_LONG
            || self.system_prompt == LEGACY_SYSTEM_PROMPT_SHORT
        {
            self.system_prompt = DEFAULT_SYSTEM_PROMPT.into();
        }
    }

    pub fn is_configured(&self) -> bool {
        !self.effective_api_key().is_empty()
    }

    pub fn effective_api_key(&self) -> String {
        let configured = self.api_key.trim();
        if !configured.is_empty() {
            return configured.to_string();
        }

        provider_env_key(&self.provider)
            .and_then(|key| std::env::var(key).ok())
            .unwrap_or_default()
    }

    pub fn is_anthropic(&self) -> bool {
        self.provider == PROVIDER_ANTHROPIC || self.endpoint.contains("api.anthropic.com")
    }

    pub fn is_openrouter(&self) -> bool {
        self.provider == PROVIDER_OPENROUTER || self.endpoint.contains("openrouter.ai")
    }
}

fn default_provider() -> String {
    PROVIDER_DEEPSEEK.into()
}

fn is_supported_provider(provider: &str) -> bool {
    matches!(
        provider,
        PROVIDER_ANTHROPIC
            | PROVIDER_DEEPSEEK
            | PROVIDER_MINIMAX
            | PROVIDER_QWEN
            | PROVIDER_OPENROUTER
    )
}

fn provider_endpoint(provider: &str) -> String {
    match provider {
        PROVIDER_ANTHROPIC => "https://api.anthropic.com/v1/messages",
        PROVIDER_MINIMAX => "https://api.minimax.io/v1/chat/completions",
        PROVIDER_QWEN => "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions",
        PROVIDER_OPENROUTER => "https://openrouter.ai/api/v1/chat/completions",
        _ => "https://api.deepseek.com/chat/completions",
    }
    .into()
}

fn provider_default_model(provider: &str) -> String {
    match provider {
        PROVIDER_ANTHROPIC => "claude-sonnet-4-5",
        PROVIDER_MINIMAX => "MiniMax-M2.7",
        PROVIDER_QWEN => "qwen3.6-plus",
        PROVIDER_OPENROUTER => "anthropic/claude-sonnet-4.5",
        _ => "deepseek-v4-pro",
    }
    .into()
}

fn provider_env_key(provider: &str) -> Option<&'static str> {
    match provider {
        PROVIDER_ANTHROPIC => Some("ANTHROPIC_API_KEY"),
        PROVIDER_DEEPSEEK => Some("DEEPSEEK_API_KEY"),
        PROVIDER_MINIMAX => Some("MINIMAX_API_KEY"),
        PROVIDER_QWEN => Some("DASHSCOPE_API_KEY"),
        PROVIDER_OPENROUTER => Some("OPENROUTER_API_KEY"),
        _ => None,
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppSettings {
    #[serde(default = "default_true")]
    pub tts_enabled: bool,
    #[serde(default = "default_tts_provider")]
    pub tts_provider: String,
    #[serde(default = "default_tts_voice")]
    pub tts_voice_type: String,
    #[serde(default = "default_true")]
    pub memory_enabled: bool,
}

impl Default for AppSettings {
    fn default() -> Self {
        Self {
            tts_enabled: true,
            tts_provider: default_tts_provider(),
            tts_voice_type: default_tts_voice(),
            memory_enabled: true,
        }
    }
}

impl AppSettings {
    pub fn normalize(&mut self) {
        if self.tts_provider != TTS_PROVIDER_EDGE && self.tts_provider != TTS_PROVIDER_SYSTEM {
            self.tts_provider = default_tts_provider();
        }

        let voice = self.tts_voice_type.trim();
        if self.tts_provider == TTS_PROVIDER_EDGE {
            if voice.is_empty() || matches!(voice, "auto" | "Tingting" | "Meijia") {
                self.tts_voice_type = DEFAULT_EDGE_TTS_VOICE.into();
            }
        } else if voice.is_empty() {
            self.tts_voice_type = default_tts_voice();
        }
    }
}

fn default_true() -> bool {
    true
}

fn default_tts_voice() -> String {
    "Tingting".into()
}

fn default_tts_provider() -> String {
    TTS_PROVIDER_SYSTEM.into()
}
