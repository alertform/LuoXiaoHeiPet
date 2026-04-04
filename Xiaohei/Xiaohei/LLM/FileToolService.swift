import Foundation

/// 文件操作工具服务 —— 给罗小黑提供操作系统文件的能力
/// 通过 LLM function calling 机制，让小黑可以帮主人查看、修改文件
class FileToolService {

    static let shared = FileToolService()

    /// 允许操作的根目录（安全限制，防止误操作系统文件）
    var allowedRootPaths: [String] = [
        NSHomeDirectory(),
    ]

    /// 工具定义（发送给 LLM 的 tools 参数）
    var toolDefinitions: [[String: Any]] {
        return [
            [
                "type": "function",
                "function": [
                    "name": "list_files",
                    "description": "列出指定目录下的文件和文件夹。用于查看主人电脑上某个目录的内容。",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "path": [
                                "type": "string",
                                "description": "要列出的目录路径，例如 ~/Desktop 或 ~/Documents"
                            ]
                        ],
                        "required": ["path"]
                    ] as [String: Any]
                ] as [String: Any]
            ],
            [
                "type": "function",
                "function": [
                    "name": "read_file",
                    "description": "读取文件内容。用于查看文本文件的内容，如 .txt, .md, .swift, .py 等。",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "path": [
                                "type": "string",
                                "description": "文件路径"
                            ],
                            "max_lines": [
                                "type": "integer",
                                "description": "最多读取的行数，默认 50"
                            ]
                        ],
                        "required": ["path"]
                    ] as [String: Any]
                ] as [String: Any]
            ],
            [
                "type": "function",
                "function": [
                    "name": "write_file",
                    "description": "创建或覆盖写入文件。注意：这会覆盖原文件内容！请先确认主人同意。",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "path": [
                                "type": "string",
                                "description": "文件路径"
                            ],
                            "content": [
                                "type": "string",
                                "description": "要写入的内容"
                            ]
                        ],
                        "required": ["path", "content"]
                    ] as [String: Any]
                ] as [String: Any]
            ],
            [
                "type": "function",
                "function": [
                    "name": "append_file",
                    "description": "在文件末尾追加内容，不会覆盖原有内容。",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "path": [
                                "type": "string",
                                "description": "文件路径"
                            ],
                            "content": [
                                "type": "string",
                                "description": "要追加的内容"
                            ]
                        ],
                        "required": ["path", "content"]
                    ] as [String: Any]
                ] as [String: Any]
            ],
            [
                "type": "function",
                "function": [
                    "name": "create_directory",
                    "description": "创建目录（文件夹），如果父目录不存在也会一起创建。",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "path": [
                                "type": "string",
                                "description": "目录路径"
                            ]
                        ],
                        "required": ["path"]
                    ] as [String: Any]
                ] as [String: Any]
            ],
            [
                "type": "function",
                "function": [
                    "name": "delete_file",
                    "description": "删除文件或空目录。危险操作，请确认主人同意后再执行。",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "path": [
                                "type": "string",
                                "description": "要删除的文件或目录路径"
                            ]
                        ],
                        "required": ["path"]
                    ] as [String: Any]
                ] as [String: Any]
            ],
            [
                "type": "function",
                "function": [
                    "name": "move_file",
                    "description": "移动或重命名文件/目录。",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "from_path": [
                                "type": "string",
                                "description": "源路径"
                            ],
                            "to_path": [
                                "type": "string",
                                "description": "目标路径"
                            ]
                        ],
                        "required": ["from_path", "to_path"]
                    ] as [String: Any]
                ] as [String: Any]
            ],
            [
                "type": "function",
                "function": [
                    "name": "file_info",
                    "description": "获取文件信息：大小、修改时间、类型等。",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "path": [
                                "type": "string",
                                "description": "文件路径"
                            ]
                        ],
                        "required": ["path"]
                    ] as [String: Any]
                ] as [String: Any]
            ],
            [
                "type": "function",
                "function": [
                    "name": "search_files",
                    "description": "在指定目录下搜索文件名包含关键词的文件。",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "directory": [
                                "type": "string",
                                "description": "搜索的根目录"
                            ],
                            "keyword": [
                                "type": "string",
                                "description": "文件名中要搜索的关键词"
                            ],
                            "max_results": [
                                "type": "integer",
                                "description": "最大返回数量，默认 20"
                            ]
                        ],
                        "required": ["directory", "keyword"]
                    ] as [String: Any]
                ] as [String: Any]
            ],
        ]
    }

    // MARK: - 执行工具调用

    /// 执行 LLM 返回的 function call
    func executeTool(name: String, arguments: [String: Any]) -> String {
        NSLog("[FileTool] 执行: \(name), 参数: \(arguments)")

        switch name {
        case "list_files":
            return listFiles(path: arguments["path"] as? String ?? "")
        case "read_file":
            return readFile(
                path: arguments["path"] as? String ?? "",
                maxLines: arguments["max_lines"] as? Int ?? 50
            )
        case "write_file":
            return writeFile(
                path: arguments["path"] as? String ?? "",
                content: arguments["content"] as? String ?? ""
            )
        case "append_file":
            return appendFile(
                path: arguments["path"] as? String ?? "",
                content: arguments["content"] as? String ?? ""
            )
        case "create_directory":
            return createDirectory(path: arguments["path"] as? String ?? "")
        case "delete_file":
            return deleteFile(path: arguments["path"] as? String ?? "")
        case "move_file":
            return moveFile(
                from: arguments["from_path"] as? String ?? "",
                to: arguments["to_path"] as? String ?? ""
            )
        case "file_info":
            return fileInfo(path: arguments["path"] as? String ?? "")
        case "search_files":
            return searchFiles(
                directory: arguments["directory"] as? String ?? "",
                keyword: arguments["keyword"] as? String ?? "",
                maxResults: arguments["max_results"] as? Int ?? 20
            )
        default:
            return "未知工具: \(name)"
        }
    }

    // MARK: - 工具实现

    private func resolvePath(_ path: String) -> String {
        let expanded = NSString(string: path).expandingTildeInPath
        return expanded
    }

    private func isPathAllowed(_ path: String) -> Bool {
        let resolved = resolvePath(path)
        return allowedRootPaths.contains { resolved.hasPrefix($0) }
    }

    private func listFiles(path: String) -> String {
        let resolved = resolvePath(path)
        guard isPathAllowed(resolved) else {
            return "权限不足：不允许访问此目录"
        }

        let fm = FileManager.default
        guard fm.fileExists(atPath: resolved) else {
            return "目录不存在: \(path)"
        }

        do {
            let items = try fm.contentsOfDirectory(atPath: resolved)
            if items.isEmpty {
                return "目录为空"
            }

            var result: [String] = []
            for item in items.sorted().prefix(50) {
                var isDir: ObjCBool = false
                let fullPath = (resolved as NSString).appendingPathComponent(item)
                fm.fileExists(atPath: fullPath, isDirectory: &isDir)
                let icon = isDir.boolValue ? "📁" : "📄"
                result.append("\(icon) \(item)")
            }

            if items.count > 50 {
                result.append("... 还有 \(items.count - 50) 个文件")
            }

            return result.joined(separator: "\n")
        } catch {
            return "读取目录失败: \(error.localizedDescription)"
        }
    }

    private func readFile(path: String, maxLines: Int) -> String {
        let resolved = resolvePath(path)
        guard isPathAllowed(resolved) else {
            return "权限不足：不允许访问此文件"
        }

        guard FileManager.default.fileExists(atPath: resolved) else {
            return "文件不存在: \(path)"
        }

        do {
            let content = try String(contentsOfFile: resolved, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            let truncated = lines.prefix(maxLines).joined(separator: "\n")

            if lines.count > maxLines {
                return truncated + "\n... (共 \(lines.count) 行，只显示前 \(maxLines) 行)"
            }
            return truncated
        } catch {
            return "读取文件失败: \(error.localizedDescription)"
        }
    }

    private func writeFile(path: String, content: String) -> String {
        let resolved = resolvePath(path)
        guard isPathAllowed(resolved) else {
            return "权限不足：不允许写入此路径"
        }

        do {
            try content.write(toFile: resolved, atomically: true, encoding: .utf8)
            return "文件已写入: \(path) (\(content.count) 字符)"
        } catch {
            return "写入失败: \(error.localizedDescription)"
        }
    }

    private func appendFile(path: String, content: String) -> String {
        let resolved = resolvePath(path)
        guard isPathAllowed(resolved) else {
            return "权限不足：不允许写入此路径"
        }

        do {
            if FileManager.default.fileExists(atPath: resolved) {
                let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: resolved))
                handle.seekToEndOfFile()
                if let data = content.data(using: .utf8) {
                    handle.write(data)
                }
                handle.closeFile()
            } else {
                try content.write(toFile: resolved, atomically: true, encoding: .utf8)
            }
            return "内容已追加到: \(path)"
        } catch {
            return "追加失败: \(error.localizedDescription)"
        }
    }

    private func createDirectory(path: String) -> String {
        let resolved = resolvePath(path)
        guard isPathAllowed(resolved) else {
            return "权限不足：不允许在此位置创建目录"
        }

        do {
            try FileManager.default.createDirectory(atPath: resolved, withIntermediateDirectories: true)
            return "目录已创建: \(path)"
        } catch {
            return "创建失败: \(error.localizedDescription)"
        }
    }

    private func deleteFile(path: String) -> String {
        let resolved = resolvePath(path)
        guard isPathAllowed(resolved) else {
            return "权限不足：不允许删除此文件"
        }

        guard FileManager.default.fileExists(atPath: resolved) else {
            return "文件不存在: \(path)"
        }

        // 安全检查：不允许删除重要系统目录
        let dangerousPaths = ["/", NSHomeDirectory(), NSHomeDirectory() + "/Desktop",
                              NSHomeDirectory() + "/Documents", NSHomeDirectory() + "/Downloads"]
        if dangerousPaths.contains(resolved) {
            return "安全限制：不允许删除此重要目录"
        }

        do {
            try FileManager.default.removeItem(atPath: resolved)
            return "已删除: \(path)"
        } catch {
            return "删除失败: \(error.localizedDescription)"
        }
    }

    private func moveFile(from: String, to: String) -> String {
        let resolvedFrom = resolvePath(from)
        let resolvedTo = resolvePath(to)
        guard isPathAllowed(resolvedFrom), isPathAllowed(resolvedTo) else {
            return "权限不足：不允许操作此路径"
        }

        do {
            try FileManager.default.moveItem(atPath: resolvedFrom, toPath: resolvedTo)
            return "已移动: \(from) → \(to)"
        } catch {
            return "移动失败: \(error.localizedDescription)"
        }
    }

    private func fileInfo(path: String) -> String {
        let resolved = resolvePath(path)
        guard isPathAllowed(resolved) else {
            return "权限不足：不允许查看此文件"
        }

        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: resolved)
            var info: [String] = []
            info.append("路径: \(path)")

            if let type = attrs[.type] as? FileAttributeType {
                info.append("类型: \(type == .typeDirectory ? "目录" : "文件")")
            }
            if let size = attrs[.size] as? Int64 {
                info.append("大小: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
            }
            if let modified = attrs[.modificationDate] as? Date {
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
                info.append("修改时间: \(fmt.string(from: modified))")
            }
            if let created = attrs[.creationDate] as? Date {
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
                info.append("创建时间: \(fmt.string(from: created))")
            }

            return info.joined(separator: "\n")
        } catch {
            return "获取信息失败: \(error.localizedDescription)"
        }
    }

    private func searchFiles(directory: String, keyword: String, maxResults: Int) -> String {
        let resolved = resolvePath(directory)
        guard isPathAllowed(resolved) else {
            return "权限不足：不允许搜索此目录"
        }

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: resolved) else {
            return "无法访问目录: \(directory)"
        }

        var results: [String] = []
        let lowKeyword = keyword.lowercased()

        while let file = enumerator.nextObject() as? String {
            if results.count >= maxResults { break }

            let fileName = (file as NSString).lastPathComponent.lowercased()
            if fileName.contains(lowKeyword) {
                var isDir: ObjCBool = false
                let fullPath = (resolved as NSString).appendingPathComponent(file)
                fm.fileExists(atPath: fullPath, isDirectory: &isDir)
                let icon = isDir.boolValue ? "📁" : "📄"
                results.append("\(icon) \(file)")
            }
        }

        if results.isEmpty {
            return "未找到包含 \"\(keyword)\" 的文件"
        }
        return results.joined(separator: "\n")
    }
}
