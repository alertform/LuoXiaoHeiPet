import Foundation

/// LLM 回复结果（可能包含文本或工具调用）
struct LLMResponse {
    let content: String
    let toolCalls: [ToolCall]

    var hasToolCalls: Bool { !toolCalls.isEmpty }
}

/// LLM 服务协议 —— 抽象 LLM 接口，方便后续切换不同的 API 提供商
protocol LLMService {

    /// 发送消息并获取回复（支持 tool calls）
    func sendMessage(
        messages: [ChatMessage],
        completion: @escaping (Result<LLMResponse, LLMError>) -> Void
    )

    /// 发送消息并获取流式回复
    func sendMessageStream(
        messages: [ChatMessage],
        onToken: @escaping (String) -> Void,
        onComplete: @escaping (Result<Void, LLMError>) -> Void
    )

    /// 取消当前请求
    func cancel()
}

/// LLM 错误类型
enum LLMError: Error, LocalizedError {
    case invalidAPIKey
    case networkError(Error)
    case rateLimited
    case serverError(Int, String)
    case decodingError(Error)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "API Key 无效，请在设置中检查"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .rateLimited:
            return "请求过于频繁，请稍后再试"
        case .serverError(let code, let message):
            return "服务器错误 (\(code)): \(message)"
        case .decodingError(let error):
            return "数据解析错误: \(error.localizedDescription)"
        case .cancelled:
            return "请求已取消"
        }
    }
}

/// 聊天消息模型
struct ChatMessage: Codable {
    let role: Role
    let content: String
    let timestamp: Date

    /// tool_calls（assistant 请求调用工具时）
    var toolCalls: [ToolCall]?
    /// tool_call_id（tool 角色回复时关联的 call id）
    var toolCallId: String?

    enum Role: String, Codable {
        case system
        case user
        case assistant
        case tool
    }

    init(role: Role, content: String, timestamp: Date = Date(), toolCalls: [ToolCall]? = nil, toolCallId: String? = nil) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
    }
}

/// LLM 工具调用
struct ToolCall: Codable {
    let id: String
    let functionName: String
    let arguments: String  // JSON string
}
