import Foundation

/// 火山引擎（豆包大模型）LLM 服务实现
/// API 文档: https://www.volcengine.com/docs/82379/1263482
class VolcanoEngineService: LLMService {

    // MARK: - Properties
    private var config: LLMConfig
    private var currentTask: URLSessionDataTask?
    private var streamSession: URLSession?
    private var streamDelegate: StreamDelegate?  // 强引用，防止 delegate 被提前释放

    // MARK: - Init
    init(config: LLMConfig) {
        self.config = config
    }

    /// 更新配置（设置页面修改后调用）
    func updateConfig(_ config: LLMConfig) {
        self.config = config
    }

    // MARK: - LLMService Protocol

    func sendMessage(
        messages: [ChatMessage],
        completion: @escaping (Result<LLMResponse, LLMError>) -> Void
    ) {
        guard config.isConfigured else {
            completion(.failure(.invalidAPIKey))
            return
        }

        let request = buildRequest(messages: messages, stream: false)

        currentTask = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                if (error as NSError).code == NSURLErrorCancelled {
                    completion(.failure(.cancelled))
                } else {
                    completion(.failure(.networkError(error)))
                }
                return
            }

            guard let data = data else {
                completion(.failure(.networkError(
                    NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "空响应"])
                )))
                return
            }

            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode != 200 {
                let body = String(data: data, encoding: .utf8) ?? "未知错误"
                NSLog("[LLM] 非流式错误 \(httpResponse.statusCode): \(String(body.prefix(200)))")
                if httpResponse.statusCode == 429 {
                    completion(.failure(.rateLimited))
                } else {
                    completion(.failure(.serverError(httpResponse.statusCode, body)))
                }
                return
            }

            // 用 JSONSerialization 解析，以支持 tool_calls
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let message = firstChoice["message"] as? [String: Any] else {
                    completion(.failure(.decodingError(
                        NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析响应"])
                    )))
                    return
                }

                let content = message["content"] as? String ?? ""
                var toolCalls: [ToolCall] = []

                // 解析 tool_calls
                if let tcArray = message["tool_calls"] as? [[String: Any]] {
                    for tc in tcArray {
                        let id = tc["id"] as? String ?? UUID().uuidString
                        if let function = tc["function"] as? [String: Any] {
                            let name = function["name"] as? String ?? ""
                            let arguments = function["arguments"] as? String ?? "{}"
                            toolCalls.append(ToolCall(id: id, functionName: name, arguments: arguments))
                        }
                    }
                }

                let response = LLMResponse(content: content, toolCalls: toolCalls)
                DispatchQueue.main.async {
                    completion(.success(response))
                }
            } catch {
                completion(.failure(.decodingError(error)))
            }
        }

        currentTask?.resume()
    }

    func sendMessageStream(
        messages: [ChatMessage],
        onToken: @escaping (String) -> Void,
        onComplete: @escaping (Result<Void, LLMError>) -> Void
    ) {
        guard config.isConfigured else {
            onComplete(.failure(.invalidAPIKey))
            return
        }

        let request = buildRequest(messages: messages, stream: true)

        // 使用自定义 delegate 处理 SSE 流
        let delegate = StreamDelegate(onToken: onToken, onComplete: { [weak self] result in
            // 流结束后清理 delegate 引用
            self?.streamDelegate = nil
            onComplete(result)
        })
        streamDelegate = delegate  // 强引用防止提前释放
        streamSession = URLSession(configuration: .default, delegate: delegate, delegateQueue: .main)
        let task = streamSession?.dataTask(with: request)
        task?.resume()
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil

        // 先保存引用再清理，避免 invalidate 过程中 delegate 被提前释放
        let session = streamSession
        streamSession = nil
        session?.invalidateAndCancel()

        // session invalidate 后再释放 delegate
        streamDelegate = nil
    }

    // MARK: - Request Building

    /// 是否启用文件工具
    var enableFileTools: Bool = true

    private func buildRequest(messages: [ChatMessage], stream: Bool) -> URLRequest {
        let url = URL(string: config.endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        // 构建消息数组（插入 system prompt）
        var apiMessages: [[String: Any]] = [
            ["role": "system", "content": config.systemPrompt]
        ]
        for msg in messages {
            if msg.role == .tool {
                // tool 消息需要包含 tool_call_id
                apiMessages.append([
                    "role": "tool",
                    "content": msg.content,
                    "tool_call_id": msg.toolCallId ?? ""
                ])
            } else if msg.role == .assistant, let toolCalls = msg.toolCalls, !toolCalls.isEmpty {
                // assistant 带 tool_calls 的消息
                let tcArray = toolCalls.map { tc -> [String: Any] in
                    return [
                        "id": tc.id,
                        "type": "function",
                        "function": [
                            "name": tc.functionName,
                            "arguments": tc.arguments
                        ]
                    ]
                }
                apiMessages.append([
                    "role": "assistant",
                    "content": msg.content,
                    "tool_calls": tcArray
                ])
            } else {
                apiMessages.append([
                    "role": msg.role.rawValue,
                    "content": msg.content
                ])
            }
        }

        var body: [String: Any] = [
            "model": config.model,
            "messages": apiMessages,
            "temperature": config.temperature,
            "max_tokens": config.maxTokens,
            "stream": stream
        ]

        // 添加文件操作工具定义
        if enableFileTools {
            body["tools"] = FileToolService.shared.toolDefinitions
        }

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        NSLog("[LLM] 请求 URL: \(url)")
        NSLog("[LLM] 模型: \(config.model), stream: \(stream), tools: \(enableFileTools)")
        NSLog("[LLM] API Key 前8位: \(String(config.apiKey.prefix(8)))...")

        return request
    }
}

// MARK: - SSE Stream Delegate

private class StreamDelegate: NSObject, URLSessionDataDelegate {
    private let onToken: (String) -> Void
    private let onComplete: (Result<Void, LLMError>) -> Void
    private var buffer = ""
    private var hasCompleted = false  // 防止 onComplete 被多次调用

    init(onToken: @escaping (String) -> Void,
         onComplete: @escaping (Result<Void, LLMError>) -> Void) {
        self.onToken = onToken
        self.onComplete = onComplete
    }

    /// 安全调用 onComplete，确保只调用一次
    private func complete(with result: Result<Void, LLMError>) {
        guard !hasCompleted else { return }
        hasCompleted = true
        onComplete(result)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        NSLog("[LLM-Stream] 收到数据: \(String(text.prefix(200)))")
        buffer += text

        // 按行解析 SSE 数据
        while let lineEnd = buffer.firstIndex(of: "\n") {
            let line = String(buffer[buffer.startIndex..<lineEnd]).trimmingCharacters(in: .whitespaces)
            buffer = String(buffer[buffer.index(after: lineEnd)...])

            guard line.hasPrefix("data: ") else { continue }
            let jsonStr = String(line.dropFirst(6))

            if jsonStr == "[DONE]" {
                complete(with: .success(()))
                return
            }

            // 解析 SSE chunk
            if let jsonData = jsonStr.data(using: .utf8),
               let chunk = try? JSONDecoder().decode(ChatCompletionChunk.self, from: jsonData),
               let delta = chunk.choices.first?.delta.content {
                if !hasCompleted {
                    onToken(delta)
                }
            }
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let httpResponse = response as? HTTPURLResponse {
            NSLog("[LLM-Stream] HTTP 状态码: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                NSLog("[LLM-Stream] ⚠️ 非200状态码!")
            }
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            if (error as NSError).code == NSURLErrorCancelled {
                NSLog("[LLM-Stream] 请求已取消")
                // 取消不回调，避免 cancel() 之后还触发状态变更
            } else {
                NSLog("[LLM-Stream] ❌ 请求失败: \(error.localizedDescription)")
                complete(with: .failure(.networkError(error)))
            }
        } else {
            NSLog("[LLM-Stream] 连接关闭")
            // 如果还没收到 [DONE]，也标记完成
            complete(with: .success(()))
        }
    }
}

// MARK: - API Response Models

/// 流式响应 chunk
private struct ChatCompletionChunk: Decodable, Sendable {
    let choices: [Choice]

    struct Choice: Decodable, Sendable {
        let delta: Delta
    }

    struct Delta: Decodable, Sendable {
        let content: String?
    }
}
