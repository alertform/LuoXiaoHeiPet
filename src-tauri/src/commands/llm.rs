use crate::{
    models::{chat::ChatMessage, config::LLMConfig},
    services::volcano_engine::VolcanoEngineService,
    AppState,
};
use tauri::{AppHandle, State};

#[tauri::command]
pub async fn send_message(
    messages: Vec<ChatMessage>,
    state: State<'_, AppState>,
) -> Result<crate::models::chat::LLMResponse, String> {
    let config = state.config.lock().await.clone();
    let svc = VolcanoEngineService::new(config);
    svc.send_message(&messages, true).await
}

#[tauri::command]
pub async fn send_message_stream(
    messages: Vec<ChatMessage>,
    app: AppHandle,
    state: State<'_, AppState>,
) -> Result<(), String> {
    let config = state.config.lock().await.clone();
    let svc = VolcanoEngineService::new(config);
    svc.send_message_stream(&messages, true, &app).await
}

#[tauri::command]
pub async fn cancel_request() -> Result<(), String> {
    // 取消由前端通过监听 llm-complete 事件来处理
    Ok(())
}

/// 获取动画帧的 asset URL（用于前端加载）
#[tauri::command]
pub fn get_animation_frames(state_name: String) -> Vec<String> {
    // 返回帧文件名列表，前端用 convertFileSrc 转换
    (0..100)
        .map(|i| format!("animations/{state_name}_{i:03}.png"))
        .take_while(|name| {
            // 检查资源文件是否存在
            tauri::utils::platform::current_exe()
                .ok()
                .and_then(|exe| exe.parent().map(|p| p.join(name)))
                .map(|p| p.exists())
                .unwrap_or(false)
        })
        .collect()
}

/// 保存 LLM 配置（供设置窗口调用）
#[tauri::command]
pub async fn save_llm_config(
    config: LLMConfig,
    state: State<'_, AppState>,
) -> Result<(), String> {
    *state.config.lock().await = config;
    Ok(())
}
