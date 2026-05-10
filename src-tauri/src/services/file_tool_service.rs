use serde_json::{json, Value};
use std::fs;
use std::path::Path;

/// 工具定义（发送给 LLM 的 tools 参数）
pub fn tool_definitions() -> Value {
    json!([
        {
            "type": "function",
            "function": {
                "name": "list_files",
                "description": "列出指定目录下的文件和文件夹",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "path": { "type": "string", "description": "目录路径，支持 ~ 开头" }
                    },
                    "required": ["path"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "read_file",
                "description": "读取文本文件内容",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "path": { "type": "string", "description": "文件路径" },
                        "max_lines": { "type": "integer", "description": "最多读取行数，默认50" }
                    },
                    "required": ["path"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "write_file",
                "description": "创建或覆盖写入文件，请确认主人同意",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "path": { "type": "string" },
                        "content": { "type": "string" }
                    },
                    "required": ["path", "content"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "append_file",
                "description": "在文件末尾追加内容",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "path": { "type": "string" },
                        "content": { "type": "string" }
                    },
                    "required": ["path", "content"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "create_directory",
                "description": "创建目录（含父级目录）",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "path": { "type": "string" }
                    },
                    "required": ["path"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "delete_file",
                "description": "删除文件或空目录，危险操作请谨慎",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "path": { "type": "string" }
                    },
                    "required": ["path"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "move_file",
                "description": "移动或重命名文件/目录",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "from_path": { "type": "string" },
                        "to_path": { "type": "string" }
                    },
                    "required": ["from_path", "to_path"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "file_info",
                "description": "获取文件信息（大小、时间、类型）",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "path": { "type": "string" }
                    },
                    "required": ["path"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "search_files",
                "description": "在目录下搜索文件名包含关键词的文件",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "directory": { "type": "string" },
                        "keyword": { "type": "string" },
                        "max_results": { "type": "integer", "description": "默认20" }
                    },
                    "required": ["directory", "keyword"]
                }
            }
        }
    ])
}

pub fn execute_tool(name: &str, arguments: &Value) -> String {
    match name {
        "list_files" => {
            let path = arguments["path"].as_str().unwrap_or("");
            list_files(path)
        }
        "read_file" => {
            let path = arguments["path"].as_str().unwrap_or("");
            let max_lines = arguments["max_lines"].as_u64().unwrap_or(50) as usize;
            read_file(path, max_lines)
        }
        "write_file" => {
            let path = arguments["path"].as_str().unwrap_or("");
            let content = arguments["content"].as_str().unwrap_or("");
            write_file(path, content)
        }
        "append_file" => {
            let path = arguments["path"].as_str().unwrap_or("");
            let content = arguments["content"].as_str().unwrap_or("");
            append_file(path, content)
        }
        "create_directory" => {
            let path = arguments["path"].as_str().unwrap_or("");
            create_directory(path)
        }
        "delete_file" => {
            let path = arguments["path"].as_str().unwrap_or("");
            delete_file(path)
        }
        "move_file" => {
            let from = arguments["from_path"].as_str().unwrap_or("");
            let to = arguments["to_path"].as_str().unwrap_or("");
            move_file(from, to)
        }
        "file_info" => {
            let path = arguments["path"].as_str().unwrap_or("");
            file_info(path)
        }
        "search_files" => {
            let dir = arguments["directory"].as_str().unwrap_or("");
            let keyword = arguments["keyword"].as_str().unwrap_or("");
            let max = arguments["max_results"].as_u64().unwrap_or(20) as usize;
            search_files(dir, keyword, max)
        }
        _ => format!("未知工具: {name}"),
    }
}

fn resolve_path(path: &str) -> std::path::PathBuf {
    if path.starts_with('~') {
        if let Some(home) = dirs::home_dir() {
            return home.join(&path[2..]);
        }
    }
    std::path::PathBuf::from(path)
}

fn is_path_allowed(path: &Path) -> bool {
    let home = dirs::home_dir().unwrap_or_default();
    path.starts_with(&home)
}

fn list_files(path: &str) -> String {
    let resolved = resolve_path(path);
    if !is_path_allowed(&resolved) {
        return "权限不足：不允许访问此目录".into();
    }
    match fs::read_dir(&resolved) {
        Err(_) => format!("目录不存在或无法访问: {path}"),
        Ok(entries) => {
            let mut items: Vec<String> = entries
                .filter_map(|e| e.ok())
                .take(50)
                .map(|e| {
                    let is_dir = e.file_type().map(|t| t.is_dir()).unwrap_or(false);
                    let icon = if is_dir { "📁" } else { "📄" };
                    format!("{icon} {}", e.file_name().to_string_lossy())
                })
                .collect();
            items.sort();
            if items.is_empty() {
                "目录为空".into()
            } else {
                items.join("\n")
            }
        }
    }
}

fn read_file(path: &str, max_lines: usize) -> String {
    let resolved = resolve_path(path);
    if !is_path_allowed(&resolved) {
        return "权限不足：不允许访问此文件".into();
    }
    match fs::read_to_string(&resolved) {
        Err(_) => format!("文件不存在或无法读取: {path}"),
        Ok(content) => {
            let lines: Vec<&str> = content.lines().collect();
            let total = lines.len();
            let truncated = lines[..total.min(max_lines)].join("\n");
            if total > max_lines {
                format!("{truncated}\n... (共 {total} 行，只显示前 {max_lines} 行)")
            } else {
                truncated
            }
        }
    }
}

fn write_file(path: &str, content: &str) -> String {
    let resolved = resolve_path(path);
    if !is_path_allowed(&resolved) {
        return "权限不足：不允许写入此路径".into();
    }
    match fs::write(&resolved, content) {
        Ok(_) => format!("文件已写入: {path} ({} 字符)", content.len()),
        Err(e) => format!("写入失败: {e}"),
    }
}

fn append_file(path: &str, content: &str) -> String {
    let resolved = resolve_path(path);
    if !is_path_allowed(&resolved) {
        return "权限不足：不允许写入此路径".into();
    }
    use std::io::Write;
    match fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(&resolved)
    {
        Ok(mut f) => match f.write_all(content.as_bytes()) {
            Ok(_) => format!("内容已追加到: {path}"),
            Err(e) => format!("追加失败: {e}"),
        },
        Err(e) => format!("打开文件失败: {e}"),
    }
}

fn create_directory(path: &str) -> String {
    let resolved = resolve_path(path);
    if !is_path_allowed(&resolved) {
        return "权限不足：不允许在此位置创建目录".into();
    }
    match fs::create_dir_all(&resolved) {
        Ok(_) => format!("目录已创建: {path}"),
        Err(e) => format!("创建失败: {e}"),
    }
}

fn delete_file(path: &str) -> String {
    let resolved = resolve_path(path);
    if !is_path_allowed(&resolved) {
        return "权限不足：不允许删除此文件".into();
    }
    let home = dirs::home_dir().unwrap_or_default();
    let dangerous = [
        home.clone(),
        home.join("Desktop"),
        home.join("Documents"),
        home.join("Downloads"),
        std::path::PathBuf::from("/"),
    ];
    if dangerous.iter().any(|d| &resolved == d) {
        return "安全限制：不允许删除此重要目录".into();
    }
    if resolved.is_dir() {
        match fs::remove_dir(&resolved) {
            Ok(_) => format!("已删除目录: {path}"),
            Err(e) => format!("删除失败: {e}"),
        }
    } else {
        match fs::remove_file(&resolved) {
            Ok(_) => format!("已删除: {path}"),
            Err(e) => format!("删除失败: {e}"),
        }
    }
}

fn move_file(from: &str, to: &str) -> String {
    let from_p = resolve_path(from);
    let to_p = resolve_path(to);
    if !is_path_allowed(&from_p) || !is_path_allowed(&to_p) {
        return "权限不足：不允许操作此路径".into();
    }
    match fs::rename(&from_p, &to_p) {
        Ok(_) => format!("已移动: {from} → {to}"),
        Err(e) => format!("移动失败: {e}"),
    }
}

fn file_info(path: &str) -> String {
    let resolved = resolve_path(path);
    if !is_path_allowed(&resolved) {
        return "权限不足：不允许查看此文件".into();
    }
    match fs::metadata(&resolved) {
        Err(e) => format!("获取信息失败: {e}"),
        Ok(meta) => {
            let kind = if meta.is_dir() { "目录" } else { "文件" };
            let size = meta.len();
            let size_str = if size < 1024 {
                format!("{size} B")
            } else if size < 1024 * 1024 {
                format!("{:.1} KB", size as f64 / 1024.0)
            } else {
                format!("{:.1} MB", size as f64 / (1024.0 * 1024.0))
            };
            format!("路径: {path}\n类型: {kind}\n大小: {size_str}")
        }
    }
}

fn search_files(directory: &str, keyword: &str, max_results: usize) -> String {
    let resolved = resolve_path(directory);
    if !is_path_allowed(&resolved) {
        return "权限不足：不允许搜索此目录".into();
    }
    let kw = keyword.to_lowercase();
    let mut results = Vec::new();
    search_recursive(&resolved, &resolved, &kw, &mut results, max_results);
    if results.is_empty() {
        format!("未找到包含 \"{keyword}\" 的文件")
    } else {
        results.join("\n")
    }
}

fn search_recursive(root: &Path, dir: &Path, keyword: &str, results: &mut Vec<String>, max: usize) {
    if results.len() >= max {
        return;
    }
    let Ok(entries) = fs::read_dir(dir) else {
        return;
    };
    for entry in entries.filter_map(|e| e.ok()) {
        if results.len() >= max {
            break;
        }
        let file_name = entry.file_name().to_string_lossy().to_lowercase();
        if file_name.contains(keyword) {
            let rel = entry
                .path()
                .strip_prefix(root)
                .unwrap_or(&entry.path())
                .to_string_lossy()
                .to_string();
            let icon = if entry.path().is_dir() {
                "📁"
            } else {
                "📄"
            };
            results.push(format!("{icon} {rel}"));
        }
        if entry.path().is_dir() {
            search_recursive(root, &entry.path(), keyword, results, max);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_path_allowed_home() {
        let home = dirs::home_dir().unwrap();
        assert!(is_path_allowed(&home.join("Documents/test.txt")));
    }

    #[test]
    fn test_path_not_allowed_system() {
        assert!(!is_path_allowed(Path::new("/etc/passwd")));
        assert!(!is_path_allowed(Path::new("/usr/local/bin")));
    }

    #[test]
    fn test_resolve_tilde() {
        let home = dirs::home_dir().unwrap();
        let resolved = resolve_path("~/Documents");
        assert_eq!(resolved, home.join("Documents"));
    }
}
