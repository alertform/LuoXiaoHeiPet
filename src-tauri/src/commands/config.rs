use crate::{models::config::{AppSettings, LLMConfig}, AppState};
use tauri::State;

#[tauri::command]
pub async fn load_config(state: State<'_, AppState>) -> Result<LLMConfig, String> {
    Ok(state.config.lock().await.clone())
}

#[tauri::command]
pub async fn save_config(config: LLMConfig, state: State<'_, AppState>) -> Result<(), String> {
    *state.config.lock().await = config;
    Ok(())
}

#[tauri::command]
pub async fn load_settings(state: State<'_, AppState>) -> Result<AppSettings, String> {
    Ok(state.settings.lock().await.clone())
}

#[tauri::command]
pub async fn save_settings(settings: AppSettings, state: State<'_, AppState>) -> Result<(), String> {
    *state.settings.lock().await = settings;
    Ok(())
}
