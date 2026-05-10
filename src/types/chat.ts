export type MessageRole = "system" | "user" | "assistant" | "tool";

export interface ToolCall {
  id: string;
  function_name: string;
  arguments: string;
}

export interface ChatMessage {
  role: MessageRole;
  content: string;
  timestamp: string;
  tool_calls?: ToolCall[];
  tool_call_id?: string;
  reasoning?: string;
}

export interface LLMResponse {
  content: string;
  tool_calls: ToolCall[];
  usage?: TokenUsage;
}

export interface TokenUsage {
  input_tokens: number;
  output_tokens: number;
  total_tokens: number;
}

export interface TokenUsageStats {
  provider: string;
  model: string;
  requests: number;
  input_tokens: number;
  output_tokens: number;
  total_tokens: number;
  last_used_at: string;
}

export type ChatState = "idle" | "waiting" | "streaming" | "toolCalling";

export function userMessage(content: string): ChatMessage {
  return { role: "user", content, timestamp: new Date().toISOString() };
}

export function assistantMessage(content: string, toolCalls?: ToolCall[], reasoning?: string): ChatMessage {
  return { role: "assistant", content, timestamp: new Date().toISOString(), tool_calls: toolCalls, reasoning };
}

export function toolMessage(content: string, toolCallId: string): ChatMessage {
  return { role: "tool", content, timestamp: new Date().toISOString(), tool_call_id: toolCallId };
}
