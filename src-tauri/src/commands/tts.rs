use crate::{models::config::AppSettings, AppState};
use tauri::{AppHandle, State};
use tauri_plugin_store::StoreExt;

const STORE_FILE: &str = "settings.json";
const KEY_APP_SETTINGS: &str = "app_settings";

#[tauri::command]
pub async fn speak_text(
    text: String,
    app: AppHandle,
    state: State<'_, AppState>,
) -> Result<(), String> {
    let settings = latest_settings(&app, &state).await;
    state
        .tts
        .lock()
        .await
        .speak(&text, &settings.tts_provider, &settings.tts_voice_type)?;
    Ok(())
}

#[tauri::command]
pub async fn stop_speaking(state: State<'_, AppState>) -> Result<(), String> {
    state.tts.lock().await.stop();
    Ok(())
}

async fn latest_settings(app: &AppHandle, state: &State<'_, AppState>) -> AppSettings {
    if let Ok(store) = app.store(STORE_FILE) {
        if let Some(val) = store.get(KEY_APP_SETTINGS) {
            if let Ok(settings) = serde_json::from_value::<AppSettings>(val) {
                let mut settings = settings;
                settings.normalize();
                *state.settings.lock().await = settings.clone();
                return settings;
            }
        }
    }

    let mut settings = state.settings.lock().await.clone();
    settings.normalize();
    settings
}
