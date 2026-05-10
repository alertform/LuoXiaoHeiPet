export interface LLMConfig {
  provider: "openrouter";
  api_key: string;
  endpoint: string;
  model: string;
  temperature: number;
  max_tokens: number;
  system_prompt: string;
}

export interface AppSettings {
  tts_enabled: boolean;
  tts_voice_type: string;
  memory_enabled: boolean;
}

export const DEFAULT_CONFIG: LLMConfig = {
  provider: "openrouter",
  api_key: "",
  endpoint: "https://openrouter.ai/api/v1/chat/completions",
  model: "anthropic/claude-sonnet-4.5",
  temperature: 0.7,
  max_tokens: 1024,
  system_prompt:
    "你是罗小黑，一只可爱的小黑猫精灵，住在主人的电脑桌面上。你性格温柔、好奇、有点调皮，偶尔会说一些俏皮话。回复要简短可爱，每次不超过两三句话，偶尔用\"喵~\"结尾。不要使用 markdown 格式，用纯文本回复。",
};
