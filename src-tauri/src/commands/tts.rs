use crate::AppState;
use tauri::State;

#[tauri::command]
pub async fn speak_text(text: String, state: State<'_, AppState>) -> Result<(), String> {
    state.tts.lock().await.speak(&text);
    Ok(())
}

#[tauri::command]
pub async fn stop_speaking(state: State<'_, AppState>) -> Result<(), String> {
    state.tts.lock().await.stop();
    Ok(())
}
