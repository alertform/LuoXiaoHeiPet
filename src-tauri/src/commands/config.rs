use crate::{
    models::config::{AppSettings, LLMConfig},
    AppState,
};
use tauri::{AppHandle, State};
use tauri_plugin_store::StoreExt;

const STORE_FILE: &str = "settings.json";
const KEY_LLM_CONFIG: &str = "llm_config";
const KEY_APP_SETTINGS: &str = "app_settings";

#[tauri::command]
pub async fn load_config(app: AppHandle, state: State<'_, AppState>) -> Result<LLMConfig, String> {
    let store = app.store(STORE_FILE).map_err(|e| e.to_string())?;
    if let Some(val) = store.get(KEY_LLM_CONFIG) {
        if let Ok(config) = serde_json::from_value::<LLMConfig>(val) {
            let mut config = config;
            config.normalize_openrouter();
            *state.config.lock().await = config.clone();
            return Ok(config);
        }
    }
    Ok(state.config.lock().await.clone())
}

#[tauri::command]
pub async fn save_config(
    config: LLMConfig,
    app: AppHandle,
    state: State<'_, AppState>,
) -> Result<(), String> {
    let mut config = config;
    config.normalize_openrouter();
    *state.config.lock().await = config.clone();
    let store = app.store(STORE_FILE).map_err(|e| e.to_string())?;
    let val = serde_json::to_value(&config).map_err(|e| e.to_string())?;
    store.set(KEY_LLM_CONFIG, val);
    store.save().map_err(|e| e.to_string())?;
    Ok(())
}

#[tauri::command]
pub async fn load_settings(
    app: AppHandle,
    state: State<'_, AppState>,
) -> Result<AppSettings, String> {
    let store = app.store(STORE_FILE).map_err(|e| e.to_string())?;
    if let Some(val) = store.get(KEY_APP_SETTINGS) {
        if let Ok(settings) = serde_json::from_value::<AppSettings>(val) {
            *state.settings.lock().await = settings.clone();
            return Ok(settings);
        }
    }
    Ok(state.settings.lock().await.clone())
}

#[tauri::command]
pub async fn save_settings(
    settings: AppSettings,
    app: AppHandle,
    state: State<'_, AppState>,
) -> Result<(), String> {
    *state.settings.lock().await = settings.clone();
    let store = app.store(STORE_FILE).map_err(|e| e.to_string())?;
    let val = serde_json::to_value(&settings).map_err(|e| e.to_string())?;
    store.set(KEY_APP_SETTINGS, val);
    store.save().map_err(|e| e.to_string())?;
    Ok(())
}
