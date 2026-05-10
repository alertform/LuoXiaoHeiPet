import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import type { ChatMessage, LLMResponse, TokenUsageStats } from "../types/chat";
import type { AppSettings, LLMConfig } from "../types/config";

// LLM
export const sendMessage = (messages: ChatMessage[]) =>
  invoke<LLMResponse>("send_message", { messages });

export const sendMessageStream = (messages: ChatMessage[]) =>
  invoke<void>("send_message_stream", { messages });

export const onLlmToken = (cb: (token: string) => void) =>
  listen<string>("llm-token", (e) => cb(e.payload));

export const onLlmReasoning = (cb: (token: string) => void) =>
  listen<string>("llm-reasoning", (e) => cb(e.payload));

export const onLlmComplete = (cb: () => void) =>
  listen<void>("llm-complete", () => cb());

// File tools
export const executeTool = (name: string, arguments_: Record<string, unknown>) =>
  invoke<string>("execute_tool", { name, arguments: JSON.stringify(arguments_) });

// Config
export const loadConfig = () => invoke<LLMConfig>("load_config");
export const saveConfig = (config: LLMConfig) => invoke<void>("save_config", { config });
export const loadSettings = () => invoke<AppSettings>("load_settings");
export const saveSettings = (settings: AppSettings) =>
  invoke<void>("save_settings", { settings });
export const loadTokenUsageStats = () =>
  invoke<TokenUsageStats[]>("load_token_usage_stats");
export const clearTokenUsageStats = () =>
  invoke<void>("clear_token_usage_stats");

// Memory
export const buildMemoryContext = () => invoke<string>("build_memory_context");
export const processConversation = (messages: ChatMessage[]) =>
  invoke<void>("process_conversation", { messages });
export const endSession = (messages: ChatMessage[]) =>
  invoke<void>("end_session", { messages });
export const clearMemory = () => invoke<void>("clear_memory");
export const setMemoryEnabled = (enabled: boolean) =>
  invoke<void>("set_memory_enabled", { enabled });

// TTS
export const speakText = (text: string) => invoke<void>("speak_text", { text });
export const stopSpeaking = () => invoke<void>("stop_speaking");
