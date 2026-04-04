import Cocoa

/// 聊天气泡弹窗 —— 自适应高度，显示在桌宠头顶
class ChatBubbleWindow: NSWindow {

    private static let bubbleWidth: CGFloat = 280
    private static let minHeight: CGFloat = 80
    private static let maxHeight: CGFloat = 400

    private var bubbleView: ChatBubbleView!

    init(origin: NSPoint, chatManager: ChatManager, onClose: @escaping () -> Void) {
        let frame = NSRect(origin: origin, size: NSSize(
            width: Self.bubbleWidth,
            height: Self.minHeight
        ))

        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .statusBar + 1

        bubbleView = ChatBubbleView(
            frame: NSRect(origin: .zero, size: frame.size),
            chatManager: chatManager,
            onClose: onClose,
            onResize: { [weak self] newHeight in
                self?.resizeBubble(to: newHeight)
            }
        )
        contentView = bubbleView

        // init 期间 bubbleView 尚未赋值，requestResize 被 guard 跳过
        // 现在补一次 resize
        bubbleView.requestResize()
    }

    override var canBecomeKey: Bool { true }

    func cleanup() {
        bubbleView?.cleanupCallbacks()
    }

    private var currentTargetHeight: CGFloat = 0

    private func resizeBubble(to contentHeight: CGFloat) {
        guard let bubbleView = bubbleView else { return }
        let targetHeight = min(max(contentHeight, Self.minHeight), Self.maxHeight)

        // 高度没变化就不刷新
        guard abs(targetHeight - currentTargetHeight) > 2 else { return }
        currentTargetHeight = targetHeight

        var newFrame = frame
        let diff = targetHeight - newFrame.height
        newFrame.origin.y -= diff
        newFrame.size.height = targetHeight
        setFrame(newFrame, display: true, animate: false)
        bubbleView.frame = NSRect(origin: .zero, size: newFrame.size)
        bubbleView.needsDisplay = true
        bubbleView.layoutContent()
    }
}

/// 聊天气泡内容视图
class ChatBubbleView: NSView {

    private let chatManager: ChatManager
    private let onClose: () -> Void
    private let onResize: (CGFloat) -> Void

    private var scrollView: NSScrollView!
    private var messagesContainer: NSStackView!
    private var inputField: NSTextField!
    private var sendButton: NSButton!
    private var historyHintLabel: NSTextField!
    private var streamingLabel: NSTextField?
    private var isStreamingComplete = true
    private var streamTokenCount: Int = 0

    /// 历史浏览状态
    private var historyOffset: Int = 0  // 0 = 最新，2 = 上一轮，4 = 上上轮...
    private var isViewingHistory = false

    private let padding: CGFloat = 12
    private let inputHeight: CGFloat = 28
    private let triHeight: CGFloat = 12

    init(frame: NSRect, chatManager: ChatManager, onClose: @escaping () -> Void, onResize: @escaping (CGFloat) -> Void) {
        self.chatManager = chatManager
        self.onClose = onClose
        self.onResize = onResize
        super.init(frame: frame)
        wantsLayer = true
        setupUI()
        setupCallbacks()
        showLatestRound()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func cleanupCallbacks() {
        chatManager.onMessageReceived = nil
        chatManager.onStreamToken = nil
        chatManager.onError = nil
        chatManager.onStateChange = nil
        chatManager.onToolCallStatus = nil
    }

    // MARK: - Drawing
    override func draw(_ dirtyRect: NSRect) {
        let bubbleRect = NSRect(
            x: 4, y: triHeight + 4,
            width: bounds.width - 8,
            height: bounds.height - triHeight - 8
        )

        let path = NSBezierPath(roundedRect: bubbleRect, xRadius: 10, yRadius: 10)

        let tri = NSBezierPath()
        let cx = bubbleRect.midX
        tri.move(to: NSPoint(x: cx - 8, y: bubbleRect.minY))
        tri.line(to: NSPoint(x: cx, y: bubbleRect.minY - triHeight))
        tri.line(to: NSPoint(x: cx + 8, y: bubbleRect.minY))
        tri.close()
        path.append(tri)

        if NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            NSColor(white: 0.15, alpha: 0.95).setFill()
        } else {
            NSColor(white: 1.0, alpha: 0.95).setFill()
        }
        path.fill()

        NSColor.separatorColor.setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }

    // MARK: - Keyboard Events
    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 126:  // 上箭头
            navigateHistory(direction: .up)
        case 125:  // 下箭头
            navigateHistory(direction: .down)
        default:
            super.keyDown(with: event)
        }
    }

    private enum HistoryDirection { case up, down }

    private func navigateHistory(direction: HistoryDirection) {
        let history = chatManager.history
        guard !history.isEmpty else { return }

        // 找出所有"轮次"的起点（每个 user 消息开始一轮）
        var rounds: [(user: Int, assistant: Int?)] = []
        for (i, msg) in history.enumerated() {
            if msg.role == .user {
                // 找对应的 assistant 回复
                let assistantIdx = (i + 1 < history.count && history[i + 1].role == .assistant) ? i + 1 : nil
                rounds.append((user: i, assistant: assistantIdx))
            }
        }

        guard !rounds.isEmpty else { return }

        switch direction {
        case .up:
            if historyOffset < rounds.count - 1 {
                historyOffset += 1
                isViewingHistory = true
            }
        case .down:
            if historyOffset > 0 {
                historyOffset -= 1
                if historyOffset == 0 {
                    isViewingHistory = false
                }
            }
        }

        // 显示对应轮次
        let roundIdx = rounds.count - 1 - historyOffset
        guard roundIdx >= 0, roundIdx < rounds.count else { return }

        clearMessages()
        let round = rounds[roundIdx]
        addBubble(text: history[round.user].content, isUser: true)
        if let aIdx = round.assistant {
            addBubble(text: history[aIdx].content, isUser: false)
        }

        // 显示位置提示
        if isViewingHistory {
            historyHintLabel.stringValue = "历史 \(historyOffset)/\(rounds.count - 1)  ↑↓翻页"
            historyHintLabel.isHidden = false
        } else {
            historyHintLabel.isHidden = true
        }

        requestResize()
    }

    // MARK: - Layout
    private func setupUI() {
        let contentX = padding
        let contentW = bounds.width - padding * 2

        // 输入区域（底部固定）
        let inputY = triHeight + padding
        inputField = NSTextField(frame: NSRect(x: contentX, y: inputY, width: contentW - 44, height: inputHeight))
        inputField.placeholderString = "跟小黑说点什么...  ↑查看历史"
        inputField.font = .systemFont(ofSize: 12)
        inputField.bezelStyle = .roundedBezel
        inputField.target = self
        inputField.action = #selector(sendMessage)
        addSubview(inputField)

        sendButton = NSButton(frame: NSRect(x: bounds.width - padding - 38, y: inputY, width: 34, height: inputHeight))
        sendButton.title = "发送"
        sendButton.bezelStyle = .rounded
        sendButton.font = .systemFont(ofSize: 11)
        sendButton.target = self
        sendButton.action = #selector(sendMessage)
        addSubview(sendButton)

        // 历史提示标签
        historyHintLabel = NSTextField(labelWithString: "")
        historyHintLabel.frame = NSRect(x: contentX, y: inputY + inputHeight + 2, width: contentW, height: 14)
        historyHintLabel.font = .systemFont(ofSize: 9)
        historyHintLabel.textColor = .tertiaryLabelColor
        historyHintLabel.alignment = .center
        historyHintLabel.isHidden = true
        addSubview(historyHintLabel)

        // 消息区域
        let hintH: CGFloat = 16
        let messagesY = inputY + inputHeight + 6 + hintH
        let messagesH = bounds.height - messagesY - padding - 4
        scrollView = NSScrollView(frame: NSRect(x: contentX, y: messagesY, width: contentW, height: max(messagesH, 10)))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        messagesContainer = NSStackView()
        messagesContainer.orientation = .vertical
        messagesContainer.alignment = .leading
        messagesContainer.spacing = 6
        messagesContainer.translatesAutoresizingMaskIntoConstraints = false

        scrollView.documentView = messagesContainer
        addSubview(scrollView)
    }

    func layoutContent() {
        let contentX = padding
        let contentW = bounds.width - padding * 2
        let inputY = triHeight + padding

        inputField.frame = NSRect(x: contentX, y: inputY, width: contentW - 44, height: inputHeight)
        sendButton.frame = NSRect(x: bounds.width - padding - 38, y: inputY, width: 34, height: inputHeight)

        historyHintLabel.frame = NSRect(x: contentX, y: inputY + inputHeight + 2, width: contentW, height: 14)

        let hintH: CGFloat = 16
        let messagesY = inputY + inputHeight + 6 + hintH
        let messagesH = bounds.height - messagesY - padding - 4
        scrollView.frame = NSRect(x: contentX, y: messagesY, width: contentW, height: max(messagesH, 10))
    }

    // MARK: - Callbacks
    private func setupCallbacks() {
        chatManager.onMessageReceived = { [weak self] message in
            DispatchQueue.main.async {
                guard let self else { return }
                if message.role == .user {
                    // 新消息来了，回到最新轮
                    self.historyOffset = 0
                    self.isViewingHistory = false
                    self.historyHintLabel.isHidden = true
                    // 清除旧的显示，只显示这轮
                    self.clearMessages()
                    self.addBubble(text: message.content, isUser: true)
                } else {
                    // 流式完成，最后刷新
                    self.streamingLabel?.sizeToFit()
                    self.scrollToBottom()
                    self.requestResize()
                    self.isStreamingComplete = true
                    self.streamingLabel = nil
                    self.streamTokenCount = 0
                }
            }
        }

        chatManager.onStreamToken = { [weak self] token in
            DispatchQueue.main.async {
                self?.appendStreamToken(token)
            }
        }

        chatManager.onError = { [weak self] error in
            DispatchQueue.main.async {
                self?.addBubble(text: "⚠️ \(error)", isUser: false, isError: true)
            }
        }

        chatManager.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                guard let self else { return }
                self.inputField.isEnabled = state == .idle
                self.sendButton.isEnabled = state == .idle

                if state == .toolCalling {
                    self.inputField.placeholderString = "小黑正在操作文件..."
                } else {
                    self.inputField.placeholderString = "跟小黑说点什么...  ↑查看历史"
                }
            }
        }

        chatManager.onToolCallStatus = { [weak self] status in
            DispatchQueue.main.async {
                if let status = status {
                    self?.addBubble(text: "🔧 \(status)", isUser: false, isError: false)
                }
            }
        }
    }

    // MARK: - Actions
    @objc private func sendMessage() {
        let text = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputField.stringValue = ""
        isStreamingComplete = false
        chatManager.send(text: text)
    }

    // MARK: - Message Display

    /// 显示最后一轮对话（最近的 user + assistant）
    private func showLatestRound() {
        let history = chatManager.history
        guard !history.isEmpty else { return }

        // 找最后一个 user 消息
        if let lastUserIdx = history.lastIndex(where: { $0.role == .user }) {
            addBubble(text: history[lastUserIdx].content, isUser: true)
            // 如果后面有 assistant 回复
            let nextIdx = lastUserIdx + 1
            if nextIdx < history.count, history[nextIdx].role == .assistant {
                addBubble(text: history[nextIdx].content, isUser: false)
            }
        }

        requestResize()
    }

    private func clearMessages() {
        for view in messagesContainer.arrangedSubviews {
            messagesContainer.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        streamingLabel = nil
    }

    private func addBubble(text: String, isUser: Bool, isError: Bool = false) {
        let maxW = scrollView.frame.width - 16
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = true
        label.maximumNumberOfLines = 0
        label.preferredMaxLayoutWidth = maxW * 0.85

        if isError {
            label.textColor = .systemRed
            label.backgroundColor = .clear
        } else if isUser {
            label.textColor = .white
            label.backgroundColor = .systemBlue
            label.wantsLayer = true
            label.layer?.cornerRadius = 8
        } else {
            label.textColor = .labelColor
            label.backgroundColor = .controlBackgroundColor
            label.wantsLayer = true
            label.layer?.cornerRadius = 8
        }

        label.sizeToFit()
        messagesContainer.addArrangedSubview(label)
        scrollToBottom()
        requestResize()
    }

    private func appendStreamToken(_ token: String) {
        if streamingLabel == nil {
            streamTokenCount = 0
            let label = NSTextField(wrappingLabelWithString: "")
            label.font = .systemFont(ofSize: 12)
            label.textColor = .labelColor
            label.isEditable = false
            label.isBordered = false
            label.drawsBackground = true
            label.backgroundColor = .controlBackgroundColor
            label.wantsLayer = true
            label.layer?.cornerRadius = 8
            label.maximumNumberOfLines = 0
            label.preferredMaxLayoutWidth = scrollView.frame.width - 30
            messagesContainer.addArrangedSubview(label)
            streamingLabel = label
        }
        streamingLabel?.stringValue += token
        streamTokenCount += 1

        // 每 5 个 token 或遇到标点时才刷新，避免闪烁
        if streamTokenCount % 5 == 0 || token.contains("\n") || token.contains("。") || token.contains("！") {
            streamingLabel?.sizeToFit()
            scrollToBottom()
            requestResize()
        }
    }

    private func scrollToBottom() {
        if let docView = scrollView.documentView {
            let point = NSPoint(x: 0, y: docView.frame.height)
            scrollView.contentView.scroll(to: point)
        }
    }

    func requestResize() {
        let fixedHeight = triHeight + padding + inputHeight + 6 + 16 + padding + 8
        let contentHeight = messagesContainer.fittingSize.height + 20
        let targetHeight = fixedHeight + contentHeight
        onResize(targetHeight)
    }
}
