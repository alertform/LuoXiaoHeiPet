use serde::{Deserialize, Serialize};

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
        Self {
            provider: default_provider(),
            api_key: String::new(),
            endpoint: openrouter_endpoint(),
            model: default_openrouter_model(),
            temperature: 0.7,
            max_tokens: 1024,
            system_prompt: "你是罗小黑，一只可爱的小黑猫精灵，住在主人的电脑桌面上。\
你性格温柔、好奇、有点调皮，偶尔会说一些俏皮话。\
你喜欢被摸头，喜欢晒太阳，会用猫咪的方式表达情感。\
回复要简短可爱，每次不超过两三句话，偶尔用\"喵~\"结尾。\
不要使用 markdown 格式，用纯文本回复。\
你可以帮主人操作电脑上的文件（查看目录、读写文件、搜索文件等），\
当主人要求时可以使用工具来完成，执行文件操作前要简要告知主人你要做什么。\
路径用 ~ 开头表示主人的家目录。"
                .into(),
        }
    }
}

impl LLMConfig {
    pub fn normalize_openrouter(&mut self) {
        self.provider = default_provider();
        self.endpoint = openrouter_endpoint();
        if self.model.trim().is_empty() || self.model == "doubao-seed-2.0-pro" {
            self.model = default_openrouter_model();
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

        std::env::var("OPENROUTER_API_KEY").unwrap_or_default()
    }

    pub fn is_openrouter(&self) -> bool {
        true
    }
}

fn default_provider() -> String {
    "openrouter".into()
}

fn openrouter_endpoint() -> String {
    "https://openrouter.ai/api/v1/chat/completions".into()
}

fn default_openrouter_model() -> String {
    "anthropic/claude-sonnet-4.5".into()
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppSettings {
    pub tts_enabled: bool,
    pub tts_voice_type: String,
    pub memory_enabled: bool,
}

impl Default for AppSettings {
    fn default() -> Self {
        Self {
            tts_enabled: true,
            tts_voice_type: "BV051_streaming".into(),
            memory_enabled: true,
        }
    }
}
