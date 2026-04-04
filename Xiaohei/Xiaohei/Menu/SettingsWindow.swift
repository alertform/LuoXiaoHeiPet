import Cocoa

/// 设置窗口 —— 配置 API Key、模型参数、TTS、记忆系统
class SettingsWindow: NSWindowController {

    // MARK: - Singleton
    static let shared = SettingsWindow()

    // MARK: - UI Components
    private var tabView: NSTabView!

    // LLM Tab
    private var apiKeyField: NSSecureTextField!
    private var endpointField: NSTextField!
    private var modelField: NSTextField!
    private var temperatureSlider: NSSlider!
    private var temperatureLabel: NSTextField!
    private var systemPromptView: NSTextView!

    // TTS Tab
    private var ttsEnabledButton: NSButton!
    private var ttsVoicePopup: NSPopUpButton!

    // Memory Tab
    private var memoryEnabledButton: NSButton!
    private var memoryInfoLabel: NSTextField!
    private var memoryProfileView: NSTextView!
    private var memoryFactsView: NSTextView!

    // MARK: - Init
    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "罗小黑桌宠 - 设置"
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
        setupUI()
        loadConfig()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        loadConfig()  // 每次打开时刷新
    }

    // MARK: - UI Setup
    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        tabView = NSTabView(frame: contentView.bounds)
        tabView.autoresizingMask = [.width, .height]

        // Tab 1: LLM 配置
        let llmTab = NSTabViewItem(identifier: "llm")
        llmTab.label = "AI 模型"
        llmTab.view = createLLMTab()
        tabView.addTabViewItem(llmTab)

        // Tab 2: TTS
        let ttsTab = NSTabViewItem(identifier: "tts")
        ttsTab.label = "语音"
        ttsTab.view = createTTSTab()
        tabView.addTabViewItem(ttsTab)

        // Tab 3: 记忆
        let memoryTab = NSTabViewItem(identifier: "memory")
        memoryTab.label = "记忆"
        memoryTab.view = createMemoryTab()
        tabView.addTabViewItem(memoryTab)

        contentView.addSubview(tabView)
    }

    // MARK: - LLM Tab

    private func createLLMTab() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 500))
        var y: CGFloat = 470
        let leftMargin: CGFloat = 16
        let fieldWidth: CGFloat = 440

        // API Key
        y -= 10
        let apiKeyLabel = makeLabel("API Key:")
        apiKeyLabel.frame = NSRect(x: leftMargin, y: y, width: fieldWidth, height: 20)
        view.addSubview(apiKeyLabel)

        y -= 26
        apiKeyField = NSSecureTextField(frame: NSRect(x: leftMargin, y: y, width: fieldWidth, height: 24))
        apiKeyField.placeholderString = "输入你的火山引擎 API Key"
        view.addSubview(apiKeyField)

        // Endpoint
        y -= 32
        let endpointLabel = makeLabel("API Endpoint:")
        endpointLabel.frame = NSRect(x: leftMargin, y: y, width: fieldWidth, height: 20)
        view.addSubview(endpointLabel)

        y -= 26
        endpointField = NSTextField(frame: NSRect(x: leftMargin, y: y, width: fieldWidth, height: 24))
        endpointField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        view.addSubview(endpointField)

        // Model
        y -= 32
        let modelLabel = makeLabel("模型 (Model):")
        modelLabel.frame = NSRect(x: leftMargin, y: y, width: fieldWidth, height: 20)
        view.addSubview(modelLabel)

        y -= 26
        modelField = NSTextField(frame: NSRect(x: leftMargin, y: y, width: fieldWidth, height: 24))
        modelField.placeholderString = "doubao-seed-2.0-pro"
        view.addSubview(modelField)

        // Temperature
        y -= 32
        temperatureLabel = makeLabel("Temperature: 0.7")
        temperatureLabel.frame = NSRect(x: leftMargin, y: y, width: fieldWidth, height: 20)
        view.addSubview(temperatureLabel)

        y -= 22
        temperatureSlider = NSSlider(frame: NSRect(x: leftMargin, y: y, width: fieldWidth, height: 20))
        temperatureSlider.minValue = 0.0
        temperatureSlider.maxValue = 2.0
        temperatureSlider.doubleValue = 0.7
        temperatureSlider.target = self
        temperatureSlider.action = #selector(temperatureChanged)
        view.addSubview(temperatureSlider)

        // System Prompt
        y -= 32
        let promptLabel = makeLabel("角色设定 (System Prompt):")
        promptLabel.frame = NSRect(x: leftMargin, y: y, width: fieldWidth, height: 20)
        view.addSubview(promptLabel)

        y -= 130
        let scrollView = NSScrollView(frame: NSRect(x: leftMargin, y: y, width: fieldWidth, height: 125))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        systemPromptView = NSTextView(frame: NSRect(x: 0, y: 0, width: fieldWidth - 20, height: 125))
        systemPromptView.isEditable = true
        systemPromptView.font = .systemFont(ofSize: 12)
        systemPromptView.isRichText = false
        systemPromptView.autoresizingMask = [.width]
        systemPromptView.textContainer?.widthTracksTextView = true
        scrollView.documentView = systemPromptView
        view.addSubview(scrollView)

        // 按钮
        y -= 40
        let saveButton = NSButton(frame: NSRect(x: fieldWidth - 60, y: y, width: 80, height: 32))
        saveButton.title = "保存"
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.target = self
        saveButton.action = #selector(saveConfig)
        view.addSubview(saveButton)

        let resetButton = NSButton(frame: NSRect(x: fieldWidth - 150, y: y, width: 80, height: 32))
        resetButton.title = "重置"
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(resetConfig)
        view.addSubview(resetButton)

        return view
    }

    // MARK: - TTS Tab

    private func createTTSTab() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 500))
        var y: CGFloat = 460
        let leftMargin: CGFloat = 16
        let fieldWidth: CGFloat = 440

        y -= 10
        ttsEnabledButton = NSButton(checkboxWithTitle: "启用语音朗读回复", target: nil, action: nil)
        ttsEnabledButton.frame = NSRect(x: leftMargin, y: y, width: 300, height: 20)
        view.addSubview(ttsEnabledButton)

        y -= 36
        let voiceLabel = makeLabel("音色（火山引擎 TTS，需单独开通）:")
        voiceLabel.frame = NSRect(x: leftMargin, y: y, width: fieldWidth, height: 20)
        view.addSubview(voiceLabel)

        y -= 28
        ttsVoicePopup = NSPopUpButton(frame: NSRect(x: leftMargin, y: y, width: fieldWidth, height: 24))
        let voices: [(String, String)] = [
            ("BV051_streaming", "奶气萌娃（推荐）"),
            ("BV700_streaming", "灿灿 - 活泼可爱"),
            ("BV705_streaming", "炀炀 - 甜美"),
            ("BV034_streaming", "知悦 - 温柔知性"),
            ("BV007_streaming", "亲切女声"),
            ("BV001_streaming", "通用女声"),
            ("BV406_streaming", "东北萌妹"),
        ]
        for (id, name) in voices {
            ttsVoicePopup.addItem(withTitle: "\(name) [\(id)]")
            ttsVoicePopup.lastItem?.representedObject = id
        }
        view.addSubview(ttsVoicePopup)

        y -= 36
        let noteLabel = makeLabel("当前默认使用 macOS 系统中文语音。如需使用火山引擎")
        noteLabel.frame = NSRect(x: leftMargin, y: y, width: fieldWidth, height: 18)
        noteLabel.textColor = .secondaryLabelColor
        noteLabel.font = .systemFont(ofSize: 11)
        view.addSubview(noteLabel)

        y -= 18
        let noteLabel2 = makeLabel("TTS 的云端音色，需在火山引擎控制台单独开通语音合成服务。")
        noteLabel2.frame = NSRect(x: leftMargin, y: y, width: fieldWidth, height: 18)
        noteLabel2.textColor = .secondaryLabelColor
        noteLabel2.font = .systemFont(ofSize: 11)
        view.addSubview(noteLabel2)

        // 保存
        y -= 44
        let saveButton = NSButton(frame: NSRect(x: fieldWidth - 60, y: y, width: 80, height: 32))
        saveButton.title = "保存"
        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(saveConfig)
        view.addSubview(saveButton)

        return view
    }

    // MARK: - Memory Tab

    private func createMemoryTab() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 500))
        var y: CGFloat = 460
        let leftMargin: CGFloat = 16
        let fieldWidth: CGFloat = 440

        y -= 10
        memoryEnabledButton = NSButton(checkboxWithTitle: "启用记忆系统（让小黑记住你说过的话）", target: nil, action: nil)
        memoryEnabledButton.frame = NSRect(x: leftMargin, y: y, width: 400, height: 20)
        view.addSubview(memoryEnabledButton)

        y -= 28
        memoryInfoLabel = makeLabel("")
        memoryInfoLabel.frame = NSRect(x: leftMargin, y: y, width: fieldWidth, height: 18)
        memoryInfoLabel.font = .systemFont(ofSize: 11)
        memoryInfoLabel.textColor = .secondaryLabelColor
        view.addSubview(memoryInfoLabel)

        // 用户画像
        y -= 30
        let profileTitle = makeLabel("主人信息（自动识别）:", bold: false)
        profileTitle.frame = NSRect(x: leftMargin, y: y, width: fieldWidth, height: 20)
        view.addSubview(profileTitle)

        y -= 70
        let profileScroll = NSScrollView(frame: NSRect(x: leftMargin, y: y, width: fieldWidth, height: 65))
        profileScroll.hasVerticalScroller = true
        profileScroll.borderType = .bezelBorder
        memoryProfileView = NSTextView(frame: NSRect(x: 0, y: 0, width: fieldWidth - 20, height: 65))
        memoryProfileView.isEditable = false
        memoryProfileView.font = .systemFont(ofSize: 12)
        memoryProfileView.isRichText = false
        memoryProfileView.autoresizingMask = [.width]
        memoryProfileView.textContainer?.widthTracksTextView = true
        profileScroll.documentView = memoryProfileView
        view.addSubview(profileScroll)

        // 记忆事实
        y -= 28
        let factsTitle = makeLabel("记忆内容:", bold: false)
        factsTitle.frame = NSRect(x: leftMargin, y: y, width: fieldWidth, height: 20)
        view.addSubview(factsTitle)

        y -= 160
        let factsScroll = NSScrollView(frame: NSRect(x: leftMargin, y: y, width: fieldWidth, height: 155))
        factsScroll.hasVerticalScroller = true
        factsScroll.borderType = .bezelBorder
        memoryFactsView = NSTextView(frame: NSRect(x: 0, y: 0, width: fieldWidth - 20, height: 155))
        memoryFactsView.isEditable = false
        memoryFactsView.font = .systemFont(ofSize: 11)
        memoryFactsView.isRichText = false
        memoryFactsView.autoresizingMask = [.width]
        memoryFactsView.textContainer?.widthTracksTextView = true
        factsScroll.documentView = memoryFactsView
        view.addSubview(factsScroll)

        // 按钮
        y -= 40
        let clearMemoryButton = NSButton(frame: NSRect(x: leftMargin, y: y, width: 120, height: 32))
        clearMemoryButton.title = "清空所有记忆"
        clearMemoryButton.bezelStyle = .rounded
        clearMemoryButton.target = self
        clearMemoryButton.action = #selector(clearMemory)
        view.addSubview(clearMemoryButton)

        let saveButton = NSButton(frame: NSRect(x: fieldWidth - 60, y: y, width: 80, height: 32))
        saveButton.title = "保存"
        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(saveConfig)
        view.addSubview(saveButton)

        return view
    }

    // MARK: - Helpers
    private func makeLabel(_ text: String, bold: Bool = false) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = bold ? .boldSystemFont(ofSize: 14) : .systemFont(ofSize: 13)
        return label
    }

    // MARK: - Config Management
    private func loadConfig() {
        let config = LLMConfig.load()
        apiKeyField.stringValue = config.apiKey
        endpointField.stringValue = config.endpoint
        modelField.stringValue = config.model
        temperatureSlider.doubleValue = config.temperature
        temperatureLabel.stringValue = String(format: "Temperature: %.1f", config.temperature)
        systemPromptView.string = config.systemPrompt

        // TTS
        let ttsEnabled = UserDefaults.standard.object(forKey: "tts.enabled") as? Bool ?? true
        let ttsVoice = UserDefaults.standard.string(forKey: "tts.voiceType") ?? "BV051_streaming"
        ttsEnabledButton.state = ttsEnabled ? .on : .off
        for i in 0..<ttsVoicePopup.numberOfItems {
            if let id = ttsVoicePopup.item(at: i)?.representedObject as? String, id == ttsVoice {
                ttsVoicePopup.selectItem(at: i)
                break
            }
        }

        // 记忆
        let memory = MemoryManager.shared
        memoryEnabledButton.state = memory.enabled ? .on : .off

        // 统计信息
        let ltm = memory.longTermMemory
        let factCount = ltm.facts.count
        let sessionCount = ltm.sessionSummaries.count
        let emotionCount = ltm.emotionalMemories.count
        memoryInfoLabel.stringValue = "已记录: \(factCount) 条事实 · \(emotionCount) 条情感 · \(sessionCount) 次会话摘要"

        // 用户画像
        if ltm.userProfile.isEmpty {
            memoryProfileView.string = "（暂无，聊天时会自动识别）"
        } else {
            memoryProfileView.string = ltm.userProfile.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        }

        // 记忆内容
        var memoryText = ""
        if !ltm.facts.isEmpty {
            memoryText += "── 事实记忆 ──\n"
            for fact in ltm.facts.suffix(20) {
                let date = Self.dateFormatter.string(from: fact.timestamp)
                memoryText += "[\(date)] \(fact.content)\n"
            }
        }
        if !ltm.emotionalMemories.isEmpty {
            memoryText += "\n── 情感记忆 ──\n"
            for em in ltm.emotionalMemories.suffix(10) {
                let date = Self.dateFormatter.string(from: em.timestamp)
                memoryText += "[\(date)] \(em.emotion): \(em.content)\n"
            }
        }
        if !ltm.sessionSummaries.isEmpty {
            memoryText += "\n── 会话摘要 ──\n"
            for ss in ltm.sessionSummaries.suffix(5) {
                let date = Self.dateFormatter.string(from: ss.date)
                memoryText += "[\(date)] \(ss.summary) (\(ss.messageCount)条消息)\n"
            }
        }
        memoryFactsView.string = memoryText.isEmpty ? "（暂无记忆，和小黑聊天后会自动积累）" : memoryText
    }

    @objc private func saveConfig() {
        let config = LLMConfig(
            apiKey: apiKeyField.stringValue,
            endpoint: endpointField.stringValue,
            model: modelField.stringValue,
            temperature: temperatureSlider.doubleValue,
            maxTokens: 1024,
            systemPrompt: systemPromptView.string
        )
        config.save()

        // 保存 TTS 设置
        UserDefaults.standard.set(ttsEnabledButton.state == .on, forKey: "tts.enabled")
        if let voiceId = ttsVoicePopup.selectedItem?.representedObject as? String {
            UserDefaults.standard.set(voiceId, forKey: "tts.voiceType")
        }

        // 保存记忆设置
        MemoryManager.shared.enabled = memoryEnabledButton.state == .on
        UserDefaults.standard.set(memoryEnabledButton.state == .on, forKey: "memory.enabled")

        // 发送通知
        NotificationCenter.default.post(
            name: .llmConfigDidChange,
            object: nil,
            userInfo: ["config": config]
        )

        window?.close()
        NSLog("[Settings] 配置已保存")
    }

    @objc private func resetConfig() {
        let defaultConfig = LLMConfig.default
        apiKeyField.stringValue = defaultConfig.apiKey
        endpointField.stringValue = defaultConfig.endpoint
        modelField.stringValue = defaultConfig.model
        temperatureSlider.doubleValue = defaultConfig.temperature
        temperatureLabel.stringValue = String(format: "Temperature: %.1f", defaultConfig.temperature)
        systemPromptView.string = defaultConfig.systemPrompt
    }

    @objc private func temperatureChanged() {
        temperatureLabel.stringValue = String(format: "Temperature: %.1f", temperatureSlider.doubleValue)
    }

    @objc private func clearMemory() {
        let alert = NSAlert()
        alert.messageText = "清空所有记忆？"
        alert.informativeText = "这将删除小黑记住的所有信息，包括主人信息、事实记忆、情感记忆和会话摘要。此操作不可撤销。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "清空")
        alert.addButton(withTitle: "取消")

        if alert.runModal() == .alertFirstButtonReturn {
            MemoryManager.shared.clearAllMemory()
            loadConfig()  // 刷新显示
            NSLog("[Settings] 记忆已清空")
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d HH:mm"
        return f
    }()
}

// MARK: - Notification
extension Notification.Name {
    static let llmConfigDidChange = Notification.Name("com.luoxiaohei.pet.llmConfigDidChange")
}
