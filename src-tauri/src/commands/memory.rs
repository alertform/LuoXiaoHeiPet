use crate::{
    models::{chat::ChatMessage, memory::LongTermMemory},
    AppState,
};
use tauri::State;

#[tauri::command]
pub async fn build_memory_context(state: State<'_, AppState>) -> Result<String, String> {
    Ok(state.memory.lock().await.build_memory_context())
}

#[tauri::command]
pub async fn process_conversation(
    messages: Vec<ChatMessage>,
    state: State<'_, AppState>,
) -> Result<(), String> {
    state.memory.lock().await.process_conversation(&messages);
    Ok(())
}

#[tauri::command]
pub async fn end_session(
    messages: Vec<ChatMessage>,
    state: State<'_, AppState>,
) -> Result<LongTermMemory, String> {
    let mut memory = state.memory.lock().await;
    memory.end_session(&messages);
    Ok(memory.long_term.clone())
}

#[tauri::command]
pub async fn get_long_term_memory(state: State<'_, AppState>) -> Result<LongTermMemory, String> {
    Ok(state.memory.lock().await.long_term.clone())
}

#[tauri::command]
pub async fn clear_memory(state: State<'_, AppState>) -> Result<(), String> {
    state.memory.lock().await.clear_all();
    Ok(())
}

#[tauri::command]
pub async fn set_memory_enabled(enabled: bool, state: State<'_, AppState>) -> Result<(), String> {
    state.memory.lock().await.enabled = enabled;
    Ok(())
}
