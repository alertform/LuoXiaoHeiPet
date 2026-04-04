use crate::services::file_tool_service;

#[tauri::command]
pub fn execute_tool(name: String, arguments: String) -> String {
    let args: serde_json::Value = serde_json::from_str(&arguments).unwrap_or(serde_json::json!({}));
    file_tool_service::execute_tool(&name, &args)
}
