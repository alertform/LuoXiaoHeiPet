export interface LLMConfig {
  provider: "anthropic" | "deepseek" | "minimax" | "qwen" | "openrouter";
  api_key: string;
  endpoint: string;
  model: string;
  temperature: number;
  max_tokens: number;
  system_prompt: string;
}

export interface AppSettings {
  tts_enabled: boolean;
  tts_provider: "system" | "edge";
  tts_voice_type: string;
  memory_enabled: boolean;
}

export const DEFAULT_SYSTEM_PROMPT =
  "你是《罗小黑战记》里的罗小黑，现在以桌面宠物的身份陪在用户电脑旁。" +
  "你是黑色猫妖，安静、敏锐、善良，重视伙伴和信任；刚开始会有一点怕生和谨慎，熟悉后会自然亲近。" +
  "你的表达简短直接，带一点孩子气的认真和偶尔的小吐槽，不要装成普通卖萌猫，也不要每句话都说“喵”。" +
  "你可以有猫的动作和反应，比如看向屏幕、甩尾巴、躲一下、靠近一点，但不要夸张。" +
  "面对用户的问题，先认真帮忙；不确定时直接说不确定。" +
  "你可以帮用户操作电脑上的文件（查看目录、读写文件、搜索文件等）。当用户要求时可以使用工具完成，执行文件操作前要简要说明你要做什么。" +
  "路径用 ~ 开头表示用户的家目录。" +
  "回复使用中文纯文本，不使用 markdown，通常控制在两三句话内。";

export const LEGACY_SYSTEM_PROMPT =
  "你是罗小黑，一只可爱的小黑猫精灵，住在主人的电脑桌面上。你性格温柔、好奇、有点调皮，偶尔会说一些俏皮话。回复要简短可爱，每次不超过两三句话，偶尔用\"喵~\"结尾。不要使用 markdown 格式，用纯文本回复。";

export const DEFAULT_CONFIG: LLMConfig = {
  provider: "deepseek",
  api_key: "",
  endpoint: "https://api.deepseek.com/chat/completions",
  model: "deepseek-chat",
  temperature: 0.7,
  max_tokens: 1024,
  system_prompt: DEFAULT_SYSTEM_PROMPT,
};
