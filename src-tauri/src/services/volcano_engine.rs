use crate::models::{
    chat::{ChatMessage, LLMResponse, MessageRole, TokenUsage, ToolCall},
    config::LLMConfig,
};
use futures_util::StreamExt;
use reqwest::{Client, RequestBuilder};
use serde_json::{json, Value};
use std::sync::Arc;
use tauri::{AppHandle, Emitter};
use tokio::sync::Mutex;

pub struct VolcanoEngineService {
    client: Client,
    config: Arc<Mutex<LLMConfig>>,
}

impl VolcanoEngineService {
    pub fn new(config: LLMConfig) -> Self {
        Self {
            client: Client::builder()
                .timeout(std::time::Duration::from_secs(30))
                .build()
                .expect("Failed to build HTTP client"),
            config: Arc::new(Mutex::new(config)),
        }
    }

    pub async fn update_config(&self, config: LLMConfig) {
        *self.config.lock().await = config;
    }

    pub async fn send_message(
        &self,
        messages: &[ChatMessage],
        enable_file_tools: bool,
    ) -> Result<LLMResponse, String> {
        let config = self.config.lock().await.clone();
        if !config.is_configured() {
            return Err("API Key 未配置，请在设置中填写".into());
        }

        let body = if config.is_anthropic() {
            build_anthropic_request_body(&config, messages, false)
        } else {
            build_request_body(&config, messages, false, enable_file_tools)
        };
        let resp = with_provider_headers(self.client.post(&config.endpoint), &config)
            .json(&body)
            .send()
            .await
            .map_err(|e| format!("网络错误: {e}"))?;

        let status = resp.status();
        let text = resp
            .text()
            .await
            .map_err(|e| format!("读取响应失败: {e}"))?;

        if !status.is_success() {
            if status.as_u16() == 429 {
                return Err("请求过于频繁，请稍后再试".into());
            }
            return Err(format!(
                "服务器错误 {}: {}",
                status,
                preview_text(&text, 300)
            ));
        }

        if config.is_anthropic() {
            parse_anthropic_response(&text)
        } else {
            parse_non_stream_response(&text)
        }
    }

    pub async fn send_message_stream(
        &self,
        messages: &[ChatMessage],
        enable_file_tools: bool,
        app: &AppHandle,
    ) -> Result<Option<TokenUsage>, String> {
        let config = self.config.lock().await.clone();
        if !config.is_configured() {
            return Err("API Key 未配置，请在设置中填写".into());
        }

        let body = if config.is_anthropic() {
            build_anthropic_request_body(&config, messages, true)
        } else {
            build_request_body(&config, messages, true, enable_file_tools)
        };
        let resp = with_provider_headers(self.client.post(&config.endpoint), &config)
            .json(&body)
            .send()
            .await
            .map_err(|e| format!("网络错误: {e}"))?;

        let status = resp.status();
        if !status.is_success() {
            let text = resp
                .text()
                .await
                .unwrap_or_else(|_| "无法读取错误响应".into());
            return Err(format!(
                "服务器错误 {}: {}",
                status,
                preview_text(&text, 300)
            ));
        }

        if config.is_anthropic() {
            return stream_anthropic_response(resp, app).await;
        }

        let mut stream = resp.bytes_stream();
        let mut buffer = String::new();
        let mut usage: Option<TokenUsage> = None;

        while let Some(chunk) = stream.next().await {
            let chunk = chunk.map_err(|e| format!("流读取错误: {e}"))?;
            let text = String::from_utf8_lossy(&chunk);
            buffer.push_str(&text);

            while let Some(newline_pos) = buffer.find('\n') {
                let line = buffer[..newline_pos].trim().to_string();
                buffer = buffer[newline_pos + 1..].to_string();

                if !line.starts_with("data: ") {
                    continue;
                }
                let json_str = &line[6..];
                if json_str == "[DONE]" {
                    let _ = app.emit("llm-complete", ());
                    return Ok(usage);
                }
                if let Ok(chunk_val) = serde_json::from_str::<Value>(json_str) {
                    if let Some(next_usage) = parse_openai_usage(&chunk_val) {
                        usage = Some(next_usage);
                    }

                    let delta = &chunk_val["choices"][0]["delta"];
                    // 思考过程
                    if let Some(reasoning) = delta["reasoning_content"]
                        .as_str()
                        .or_else(|| delta["reasoning"].as_str())
                    {
                        if !reasoning.is_empty() {
                            let _ = app.emit("llm-reasoning", reasoning);
                        }
                    }
                    // 正式回复
                    if let Some(token) = delta["content"].as_str() {
                        if !token.is_empty() {
                            let _ = app.emit("llm-token", token);
                        }
                    }
                }
            }
        }

        let _ = app.emit("llm-complete", ());
        Ok(usage)
    }
}

fn with_provider_headers(request: RequestBuilder, config: &LLMConfig) -> RequestBuilder {
    if config.is_anthropic() {
        return request
            .header("x-api-key", config.effective_api_key())
            .header("anthropic-version", "2023-06-01");
    }

    let request = request.bearer_auth(config.effective_api_key());

    if config.is_openrouter() {
        request
            .header("HTTP-Referer", "https://github.com/alertform/LuoXiaoHeiPet")
            .header("X-OpenRouter-Title", "Luo Xiaohei Pet")
    } else {
        request
    }
}

async fn stream_anthropic_response(
    resp: reqwest::Response,
    app: &AppHandle,
) -> Result<Option<TokenUsage>, String> {
    let mut stream = resp.bytes_stream();
    let mut buffer = String::new();
    let mut usage = TokenUsage::default();

    while let Some(chunk) = stream.next().await {
        let chunk = chunk.map_err(|e| format!("流读取错误: {e}"))?;
        let text = String::from_utf8_lossy(&chunk);
        buffer.push_str(&text);

        while let Some(newline_pos) = buffer.find('\n') {
            let line = buffer[..newline_pos].trim().to_string();
            buffer = buffer[newline_pos + 1..].to_string();

            if !line.starts_with("data: ") {
                continue;
            }

            let json_str = &line[6..];
            if let Ok(chunk_val) = serde_json::from_str::<Value>(json_str) {
                if let Some(next_usage) = parse_anthropic_usage(&chunk_val) {
                    if next_usage.input_tokens > 0 {
                        usage.input_tokens = next_usage.input_tokens;
                    }
                    if next_usage.output_tokens > 0 {
                        usage.output_tokens = next_usage.output_tokens;
                    }
                    usage.total_tokens = usage.input_tokens + usage.output_tokens;
                }

                match chunk_val["type"].as_str().unwrap_or_default() {
                    "content_block_delta" => {
                        let delta = &chunk_val["delta"];
                        if let Some(token) = delta["text"].as_str() {
                            if !token.is_empty() {
                                let _ = app.emit("llm-token", token);
                            }
                        }
                        if let Some(reasoning) = delta["thinking"].as_str() {
                            if !reasoning.is_empty() {
                                let _ = app.emit("llm-reasoning", reasoning);
                            }
                        }
                    }
                    "message_stop" => {
                        let _ = app.emit("llm-complete", ());
                        return Ok(non_empty_usage(usage));
                    }
                    "error" => {
                        return Err(format!("Anthropic 错误: {}", chunk_val["error"]));
                    }
                    _ => {}
                }
            }
        }
    }

    let _ = app.emit("llm-complete", ());
    Ok(non_empty_usage(usage))
}

fn build_anthropic_request_body(
    config: &LLMConfig,
    messages: &[ChatMessage],
    stream: bool,
) -> Value {
    let mut system_parts = vec![config.system_prompt.clone()];
    let mut api_messages: Vec<Value> = Vec::new();

    for msg in messages {
        match msg.role {
            MessageRole::System => {
                if !msg.content.trim().is_empty() {
                    system_parts.push(msg.content.clone());
                }
            }
            MessageRole::User => {
                api_messages.push(json!({ "role": "user", "content": msg.content }));
            }
            MessageRole::Assistant => {
                api_messages.push(json!({ "role": "assistant", "content": msg.content }));
            }
            MessageRole::Tool => {
                api_messages.push(json!({
                    "role": "user",
                    "content": format!("工具返回结果：{}", msg.content)
                }));
            }
        }
    }

    json!({
        "model": config.model,
        "system": system_parts.join("\n\n"),
        "messages": api_messages,
        "temperature": config.temperature,
        "max_tokens": config.max_tokens,
        "stream": stream
    })
}

fn build_request_body(
    config: &LLMConfig,
    messages: &[ChatMessage],
    stream: bool,
    enable_file_tools: bool,
) -> Value {
    let mut api_messages: Vec<Value> =
        vec![json!({ "role": "system", "content": config.system_prompt })];

    for msg in messages {
        let role = match msg.role {
            MessageRole::System => "system",
            MessageRole::User => "user",
            MessageRole::Assistant => "assistant",
            MessageRole::Tool => "tool",
        };

        if matches!(msg.role, MessageRole::Tool) {
            api_messages.push(json!({
                "role": "tool",
                "content": msg.content,
                "tool_call_id": msg.tool_call_id.as_deref().unwrap_or("")
            }));
        } else if matches!(msg.role, MessageRole::Assistant) {
            if let Some(tool_calls) = &msg.tool_calls {
                let tc_array: Vec<Value> = tool_calls
                    .iter()
                    .map(|tc| {
                        json!({
                            "id": tc.id,
                            "type": "function",
                            "function": {
                                "name": tc.function_name,
                                "arguments": tc.arguments
                            }
                        })
                    })
                    .collect();
                api_messages.push(json!({
                    "role": "assistant",
                    "content": msg.content,
                    "tool_calls": tc_array
                }));
            } else {
                api_messages.push(json!({ "role": role, "content": msg.content }));
            }
        } else {
            api_messages.push(json!({ "role": role, "content": msg.content }));
        }
    }

    let mut body = json!({
        "model": config.model,
        "messages": api_messages,
        "temperature": config.temperature,
        "max_tokens": config.max_tokens,
        "stream": stream
    });

    if stream {
        body["stream_options"] = json!({ "include_usage": true });
    }

    if enable_file_tools {
        body["tools"] = crate::services::file_tool_service::tool_definitions();
    }

    body
}

fn parse_non_stream_response(text: &str) -> Result<LLMResponse, String> {
    let val: Value = serde_json::from_str(text).map_err(|e| format!("JSON 解析失败: {e}"))?;

    let message = &val["choices"][0]["message"];
    let content = message["content"].as_str().unwrap_or("").to_string();

    let mut tool_calls = Vec::new();
    if let Some(tcs) = message["tool_calls"].as_array() {
        for tc in tcs {
            let id = tc["id"].as_str().unwrap_or("").to_string();
            let name = tc["function"]["name"].as_str().unwrap_or("").to_string();
            let args = tc["function"]["arguments"]
                .as_str()
                .unwrap_or("{}")
                .to_string();
            tool_calls.push(ToolCall {
                id,
                function_name: name,
                arguments: args,
            });
        }
    }

    Ok(LLMResponse {
        content,
        tool_calls,
        usage: parse_openai_usage(&val),
    })
}

fn parse_anthropic_response(text: &str) -> Result<LLMResponse, String> {
    let val: Value = serde_json::from_str(text).map_err(|e| format!("JSON 解析失败: {e}"))?;
    let content = val["content"]
        .as_array()
        .map(|blocks| {
            blocks
                .iter()
                .filter_map(|block| block["text"].as_str())
                .collect::<Vec<_>>()
                .join("")
        })
        .unwrap_or_default();

    Ok(LLMResponse {
        content,
        tool_calls: Vec::new(),
        usage: parse_anthropic_usage(&val),
    })
}

fn parse_openai_usage(val: &Value) -> Option<TokenUsage> {
    let usage = val.get("usage")?;
    let input_tokens = usage["prompt_tokens"]
        .as_u64()
        .or_else(|| usage["input_tokens"].as_u64())
        .unwrap_or_default();
    let output_tokens = usage["completion_tokens"]
        .as_u64()
        .or_else(|| usage["output_tokens"].as_u64())
        .unwrap_or_default();
    let total_tokens = usage["total_tokens"]
        .as_u64()
        .unwrap_or(input_tokens + output_tokens);
    non_empty_usage(TokenUsage {
        input_tokens,
        output_tokens,
        total_tokens,
    })
}

fn parse_anthropic_usage(val: &Value) -> Option<TokenUsage> {
    let usage = val
        .get("usage")
        .or_else(|| val.get("message").and_then(|message| message.get("usage")))?;
    let input_tokens = usage["input_tokens"].as_u64().unwrap_or_default();
    let output_tokens = usage["output_tokens"].as_u64().unwrap_or_default();
    non_empty_usage(TokenUsage {
        input_tokens,
        output_tokens,
        total_tokens: input_tokens + output_tokens,
    })
}

fn non_empty_usage(usage: TokenUsage) -> Option<TokenUsage> {
    if usage.input_tokens == 0 && usage.output_tokens == 0 && usage.total_tokens == 0 {
        None
    } else {
        Some(usage)
    }
}

fn preview_text(text: &str, max_chars: usize) -> String {
    text.chars().take(max_chars).collect()
}
