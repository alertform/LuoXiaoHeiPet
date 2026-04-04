use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LLMConfig {
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
            api_key: String::new(),
            endpoint: "https://ark.cn-beijing.volces.com/api/coding/v3/chat/completions".into(),
            model: "doubao-seed-2.0-pro".into(),
            temperature: 0.7,
            max_tokens: 1024,
            system_prompt: "你是罗小黑，一只可爱的小黑猫精灵，住在主人的电脑桌面上。\
你性格温柔、好奇、有点调皮，偶尔会说一些俏皮话。\
你喜欢被摸头，喜欢晒太阳，会用猫咪的方式表达情感。\
回复要简短可爱，每次不超过两三句话，偶尔用\"喵~\"结尾。\
不要使用 markdown 格式，用纯文本回复。\
你可以帮主人操作电脑上的文件（查看目录、读写文件、搜索文件等），\
当主人要求时可以使用工具来完成，执行文件操作前要简要告知主人你要做什么。\
路径用 ~ 开头表示主人的家目录。".into(),
        }
    }
}

impl LLMConfig {
    pub fn is_configured(&self) -> bool {
        !self.api_key.is_empty()
    }
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
