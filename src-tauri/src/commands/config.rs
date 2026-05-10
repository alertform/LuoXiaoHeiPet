use crate::{
    models::{
        chat::{TokenUsage, TokenUsageStats},
        config::{AppSettings, LLMConfig},
    },
    AppState,
};
use chrono::Utc;
use tauri::{AppHandle, State};
use tauri_plugin_store::StoreExt;

const STORE_FILE: &str = "settings.json";
const KEY_LLM_CONFIG: &str = "llm_config";
const KEY_APP_SETTINGS: &str = "app_settings";
const KEY_TOKEN_USAGE_STATS: &str = "token_usage_stats";

#[tauri::command]
pub async fn load_config(app: AppHandle, state: State<'_, AppState>) -> Result<LLMConfig, String> {
    let store = app.store(STORE_FILE).map_err(|e| e.to_string())?;
    if let Some(val) = store.get(KEY_LLM_CONFIG) {
        if let Ok(config) = serde_json::from_value::<LLMConfig>(val) {
            let mut config = config;
            config.normalize_provider();
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
    config.normalize_provider();
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
            let mut settings = settings;
            settings.normalize();
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
    let mut settings = settings;
    settings.normalize();
    *state.settings.lock().await = settings.clone();
    let store = app.store(STORE_FILE).map_err(|e| e.to_string())?;
    let val = serde_json::to_value(&settings).map_err(|e| e.to_string())?;
    store.set(KEY_APP_SETTINGS, val);
    store.save().map_err(|e| e.to_string())?;
    Ok(())
}

#[tauri::command]
pub async fn load_token_usage_stats(app: AppHandle) -> Result<Vec<TokenUsageStats>, String> {
    read_token_usage_stats(&app)
}

#[tauri::command]
pub async fn clear_token_usage_stats(app: AppHandle) -> Result<(), String> {
    let store = app.store(STORE_FILE).map_err(|e| e.to_string())?;
    store.set(KEY_TOKEN_USAGE_STATS, serde_json::json!([]));
    store.save().map_err(|e| e.to_string())?;
    Ok(())
}

pub(crate) fn record_token_usage(
    app: &AppHandle,
    config: &LLMConfig,
    usage: &TokenUsage,
) -> Result<(), String> {
    if usage.input_tokens == 0 && usage.output_tokens == 0 && usage.total_tokens == 0 {
        return Ok(());
    }

    let mut stats = read_token_usage_stats(app)?;
    let now = Utc::now().to_rfc3339();
    let total_tokens = if usage.total_tokens > 0 {
        usage.total_tokens
    } else {
        usage.input_tokens + usage.output_tokens
    };

    if let Some(entry) = stats
        .iter_mut()
        .find(|entry| entry.provider == config.provider && entry.model == config.model)
    {
        entry.requests += 1;
        entry.input_tokens += usage.input_tokens;
        entry.output_tokens += usage.output_tokens;
        entry.total_tokens += total_tokens;
        entry.last_used_at = now;
    } else {
        stats.push(TokenUsageStats {
            provider: config.provider.clone(),
            model: config.model.clone(),
            requests: 1,
            input_tokens: usage.input_tokens,
            output_tokens: usage.output_tokens,
            total_tokens,
            last_used_at: now,
        });
    }

    stats.sort_by(|a, b| b.last_used_at.cmp(&a.last_used_at));
    write_token_usage_stats(app, &stats)
}

fn read_token_usage_stats(app: &AppHandle) -> Result<Vec<TokenUsageStats>, String> {
    let store = app.store(STORE_FILE).map_err(|e| e.to_string())?;
    if let Some(val) = store.get(KEY_TOKEN_USAGE_STATS) {
        return serde_json::from_value::<Vec<TokenUsageStats>>(val).map_err(|e| e.to_string());
    }
    Ok(Vec::new())
}

fn write_token_usage_stats(app: &AppHandle, stats: &[TokenUsageStats]) -> Result<(), String> {
    let store = app.store(STORE_FILE).map_err(|e| e.to_string())?;
    let val = serde_json::to_value(stats).map_err(|e| e.to_string())?;
    store.set(KEY_TOKEN_USAGE_STATS, val);
    store.save().map_err(|e| e.to_string())?;
    Ok(())
}
