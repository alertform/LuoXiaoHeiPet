import Foundation

/// 聊天管理器 —— 管理对话历史、LLM 交互、记忆系统和工具调用
class ChatManager {

    // MARK: - Properties
    private var llmService: LLMService
    let ttsService = TTSService()
    let memoryManager = MemoryManager.shared
    private(set) var history: [ChatMessage] = []

    /// 最大保留的历史消息数
    private let maxHistoryCount = 20
    /// 工具调用最大循环次数（防止无限循环）
    private let maxToolCallRounds = 5

    /// 状态回调
    var onMessageReceived: ((ChatMessage) -> Void)?
    var onStreamToken: ((String) -> Void)?
    var onStateChange: ((ChatState) -> Void)?
    var onError: ((String) -> Void)?
    /// 工具调用状态通知（nil 表示状态结束）
    var onToolCallStatus: ((String?) -> Void)?

    private(set) var state: ChatState = .idle {
        didSet { onStateChange?(state) }
    }

    // MARK: - Chat State
    enum ChatState {
        case idle
        case waiting
        case streaming
        case toolCalling  // 正在执行工具调用
    }

    // MARK: - Init
    init(llmService: LLMService) {
        self.llmService = llmService
        loadHistory()
    }

    // MARK: - Public API

    func updateLLMService(_ service: LLMService) {
        llmService.cancel()
        llmService = service
    }

    /// 发送用户消息
    func send(text: String) {
        let userMessage = ChatMessage(role: .user, content: text)
        history.append(userMessage)
        onMessageReceived?(userMessage)

        state = .waiting
        sendToLLM(toolCallRound: 0)
    }

    /// 取消当前请求
    func cancelCurrentRequest() {
        llmService.cancel()
        state = .idle
    }

    /// 清空聊天历史
    func clearHistory() {
        history.removeAll()
        saveHistory()
    }

    /// 结束当前会话
    func endSession() {
        memoryManager.endSession(messages: history)
        saveHistory()
    }

    // MARK: - LLM 请求（支持工具调用循环）

    private func sendToLLM(toolCallRound: Int) {
        // 构建消息列表
        var recentHistory = Array(history.suffix(maxHistoryCount))

        // 注入记忆上下文
        let memoryContext = memoryManager.buildMemoryContext()
        if !memoryContext.isEmpty {
            let memoryMessage = ChatMessage(role: .system, content: memoryContext)
            recentHistory.insert(memoryMessage, at: 0)
        }

        var streamedContent = ""

        llmService.sendMessageStream(
            messages: recentHistory,
            onToken: { [weak self] token in
                guard let self else { return }
                self.state = .streaming
                streamedContent += token
                self.onStreamToken?(token)
            },
            onComplete: { [weak self] result in
                guard let self else { return }
                switch result {
                case .success:
                    if streamedContent.isEmpty {
                        // 流式回复为空，可能是 tool call（流式不支持）
                        // 尝试非流式请求
                        self.sendNonStreaming(messages: recentHistory, toolCallRound: toolCallRound)
                        return
                    }

                    let assistantMessage = ChatMessage(role: .assistant, content: streamedContent)
                    self.history.append(assistantMessage)
                    self.onMessageReceived?(assistantMessage)

                    // 提取记忆
                    self.memoryManager.processConversation(messages: self.history)

                    // TTS
                    if self.ttsService.enabled, !streamedContent.isEmpty {
                        let apiKey = LLMConfig.load().apiKey
                        self.ttsService.speak(streamedContent, apiKey: apiKey)
                    }

                    self.state = .idle

                case .failure(let error):
                    self.onError?(error.localizedDescription)
                    self.state = .idle
                }
            }
        )
    }

    /// 非流式请求（用于处理 tool calling）
    private func sendNonStreaming(messages: [ChatMessage], toolCallRound: Int) {
        guard toolCallRound < maxToolCallRounds else {
            onError?("工具调用次数过多，已停止")
            state = .idle
            return
        }

        llmService.sendMessage(messages: messages) { [weak self] result in
            guard let self else { return }

            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if response.hasToolCalls {
                        // LLM 请求调用工具
                        NSLog("[Chat] LLM 请求工具调用: \(response.toolCalls.map { $0.functionName })")
                        self.handleToolCalls(
                            response.toolCalls,
                            assistantContent: response.content,
                            toolCallRound: toolCallRound
                        )
                    } else {
                        // 普通文本回复
                        let text = response.content
                        if !text.isEmpty {
                            let assistantMessage = ChatMessage(role: .assistant, content: text)
                            self.history.append(assistantMessage)
                            self.onMessageReceived?(assistantMessage)
                            self.onStreamToken?(text)  // 显示到气泡

                            self.memoryManager.processConversation(messages: self.history)

                            if self.ttsService.enabled {
                                let apiKey = LLMConfig.load().apiKey
                                self.ttsService.speak(text, apiKey: apiKey)
                            }
                        }
                        self.state = .idle
                    }

                case .failure(let error):
                    self.onError?(error.localizedDescription)
                    self.state = .idle
                }
            }
        }
    }

    // MARK: - Tool Call 处理

    /// 处理 LLM 返回的 tool calls
    func handleToolCalls(_ toolCalls: [ToolCall], assistantContent: String, toolCallRound: Int) {
        state = .toolCalling

        // 把 assistant 的 tool_calls 消息加入历史
        let assistantMsg = ChatMessage(
            role: .assistant,
            content: assistantContent,
            toolCalls: toolCalls
        )
        history.append(assistantMsg)

        // 执行每个工具调用
        for toolCall in toolCalls {
            onToolCallStatus?("正在执行: \(toolCall.functionName)...")

            // 解析参数
            var args: [String: Any] = [:]
            if let data = toolCall.arguments.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                args = parsed
            }

            // 执行工具
            let result = FileToolService.shared.executeTool(name: toolCall.functionName, arguments: args)
            NSLog("[Tool] \(toolCall.functionName) 结果: \(String(result.prefix(200)))")

            // 把工具结果加入历史
            let toolMsg = ChatMessage(
                role: .tool,
                content: result,
                toolCallId: toolCall.id
            )
            history.append(toolMsg)
        }

        onToolCallStatus?(nil)

        // 继续发送给 LLM，让它基于工具结果生成回复
        sendToLLM(toolCallRound: toolCallRound + 1)
    }

    // MARK: - Persistence

    private static let historyKey = "com.luoxiaohei.pet.chatHistory"

    func saveHistory() {
        // 只保存 user 和 assistant 消息（不保存 system/tool）
        let savableHistory = history.filter { $0.role == .user || $0.role == .assistant }
        let recentHistory = Array(savableHistory.suffix(maxHistoryCount))
        if let data = try? JSONEncoder().encode(recentHistory) {
            UserDefaults.standard.set(data, forKey: Self.historyKey)
        }
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: Self.historyKey),
              let messages = try? JSONDecoder().decode([ChatMessage].self, from: data) else {
            return
        }
        history = messages
    }
}
