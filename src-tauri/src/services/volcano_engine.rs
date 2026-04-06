use crate::models::{
    chat::{ChatMessage, LLMResponse, MessageRole, ToolCall},
    config::LLMConfig,
};
use futures_util::StreamExt;
use reqwest::Client;
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

        let body = build_request_body(&config, messages, false, enable_file_tools);
        let resp = self
            .client
            .post(&config.endpoint)
            .bearer_auth(&config.api_key)
            .json(&body)
            .send()
            .await
            .map_err(|e| format!("网络错误: {e}"))?;

        let status = resp.status();
        let text = resp.text().await.map_err(|e| format!("读取响应失败: {e}"))?;

        if !status.is_success() {
            if status.as_u16() == 429 {
                return Err("请求过于频繁，请稍后再试".into());
            }
            return Err(format!("服务器错误 {}: {}", status, &text[..text.len().min(200)]));
        }

        parse_non_stream_response(&text)
    }

    pub async fn send_message_stream(
        &self,
        messages: &[ChatMessage],
        enable_file_tools: bool,
        app: &AppHandle,
    ) -> Result<(), String> {
        let config = self.config.lock().await.clone();
        if !config.is_configured() {
            return Err("API Key 未配置，请在设置中填写".into());
        }

        let body = build_request_body(&config, messages, true, enable_file_tools);
        let resp = self
            .client
            .post(&config.endpoint)
            .bearer_auth(&config.api_key)
            .json(&body)
            .send()
            .await
            .map_err(|e| format!("网络错误: {e}"))?;

        if !resp.status().is_success() {
            return Err(format!("服务器错误 {}", resp.status()));
        }

        let mut stream = resp.bytes_stream();
        let mut buffer = String::new();

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
                    return Ok(());
                }
                if let Ok(chunk_val) = serde_json::from_str::<Value>(json_str) {
                    let delta = &chunk_val["choices"][0]["delta"];
                    // 思考过程
                    if let Some(reasoning) = delta["reasoning_content"].as_str() {
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
        Ok(())
    }
}

fn build_request_body(
    config: &LLMConfig,
    messages: &[ChatMessage],
    stream: bool,
    enable_file_tools: bool,
) -> Value {
    let mut api_messages: Vec<Value> = vec![
        json!({ "role": "system", "content": config.system_prompt })
    ];

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
                    .map(|tc| json!({
                        "id": tc.id,
                        "type": "function",
                        "function": {
                            "name": tc.function_name,
                            "arguments": tc.arguments
                        }
                    }))
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

    if enable_file_tools {
        body["tools"] = crate::services::file_tool_service::tool_definitions();
    }

    body
}

fn parse_non_stream_response(text: &str) -> Result<LLMResponse, String> {
    let val: Value =
        serde_json::from_str(text).map_err(|e| format!("JSON 解析失败: {e}"))?;

    let message = &val["choices"][0]["message"];
    let content = message["content"].as_str().unwrap_or("").to_string();

    let mut tool_calls = Vec::new();
    if let Some(tcs) = message["tool_calls"].as_array() {
        for tc in tcs {
            let id = tc["id"].as_str().unwrap_or("").to_string();
            let name = tc["function"]["name"].as_str().unwrap_or("").to_string();
            let args = tc["function"]["arguments"].as_str().unwrap_or("{}").to_string();
            tool_calls.push(ToolCall {
                id,
                function_name: name,
                arguments: args,
            });
        }
    }

    Ok(LLMResponse { content, tool_calls })
}
