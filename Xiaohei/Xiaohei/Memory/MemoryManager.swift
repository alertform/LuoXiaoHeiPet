import Foundation

/// 多层记忆系统 —— 让罗小黑拥有短期会话记忆和跨会话的长期记忆
///
/// 架构：
///   ┌─────────────────────────────────────┐
///   │  Layer 1: 工作记忆（Working Memory） │  ← 当前对话上下文，最近 N 条消息
///   ├─────────────────────────────────────┤
///   │  Layer 2: 会话记忆（Session Memory） │  ← 本次会话摘要 + 话题，app 运行期间保持
///   ├─────────────────────────────────────┤
///   │  Layer 3: 长期记忆（Long-term Memory）│  ← 跨会话持久化：用户画像、重要事实、情感记忆
///   └─────────────────────────────────────┘
///
class MemoryManager {

    static let shared = MemoryManager()

    // MARK: - Layer 1: 工作记忆（由 ChatManager.history 承担，这里不重复存储）

    // MARK: - Layer 2: 会话记忆
    private(set) var sessionTopics: [String] = []
    private(set) var sessionSummary: String = ""
    private var sessionMessageCount: Int = 0

    // MARK: - Layer 3: 长期记忆
    private(set) var longTermMemory: LongTermMemory

    // MARK: - 配置
    var enabled: Bool = true
    /// 每隔多少轮对话触发一次记忆提取
    var extractionInterval: Int = 6

    // MARK: - Init
    private init() {
        longTermMemory = LongTermMemory.load()
        NSLog("[Memory] 长期记忆加载完成: \(longTermMemory.facts.count) 条事实, \(longTermMemory.sessionSummaries.count) 条会话摘要")
    }

    // MARK: - 构建 LLM 记忆上下文

    /// 生成注入到 system prompt 中的记忆上下文
    func buildMemoryContext() -> String {
        guard enabled else { return "" }

        var parts: [String] = []

        // 用户画像
        if !longTermMemory.userProfile.isEmpty {
            let profileStr = longTermMemory.userProfile.map { "\($0.key): \($0.value)" }.joined(separator: "、")
            parts.append("【主人信息】\(profileStr)")
        }

        // 长期事实记忆（最近 15 条）
        let recentFacts = longTermMemory.facts.suffix(15)
        if !recentFacts.isEmpty {
            let factsStr = recentFacts.map { "- \($0.content)" }.joined(separator: "\n")
            parts.append("【记住的事情】\n\(factsStr)")
        }

        // 情感记忆
        let recentEmotions = longTermMemory.emotionalMemories.suffix(5)
        if !recentEmotions.isEmpty {
            let emotionStr = recentEmotions.map { "- \($0.content)（\($0.emotion)）" }.joined(separator: "\n")
            parts.append("【情感记忆】\n\(emotionStr)")
        }

        // 最近几次会话摘要（提供连续感）
        let recentSessions = longTermMemory.sessionSummaries.suffix(3)
        if !recentSessions.isEmpty {
            let summaryStr = recentSessions.map { summary in
                let dateStr = Self.dateFormatter.string(from: summary.date)
                return "- [\(dateStr)] \(summary.summary)"
            }.joined(separator: "\n")
            parts.append("【最近的聊天记忆】\n\(summaryStr)")
        }

        // 本次会话记忆
        if !sessionSummary.isEmpty {
            parts.append("【本次聊天概要】\(sessionSummary)")
        }
        if !sessionTopics.isEmpty {
            parts.append("【本次聊过的话题】\(sessionTopics.joined(separator: "、"))")
        }

        if parts.isEmpty { return "" }

        return "\n\n--- 小黑的记忆 ---\n" + parts.joined(separator: "\n\n") +
               "\n--- 记忆结束 ---\n" +
               "（请自然地运用这些记忆，不要直接说'根据我的记忆'，而是像真的记得一样自然提起。）"
    }

    // MARK: - 对话后处理：提取记忆

    /// 每轮对话后调用，从最近的消息中提取记忆
    func processConversation(messages: [ChatMessage]) {
        guard enabled else { return }

        sessionMessageCount += 1

        // 提取用户消息中的关键信息
        let recentUserMessages = messages.suffix(4).filter { $0.role == .user }
        for msg in recentUserMessages {
            extractMemoryFromText(msg.content, timestamp: msg.timestamp)
        }

        // 每 N 轮更新会话摘要
        if sessionMessageCount % extractionInterval == 0 {
            updateSessionSummary(from: messages)
        }
    }

    /// 从用户文本中提取记忆（基于规则的轻量级提取）
    private func extractMemoryFromText(_ text: String, timestamp: Date) {
        let lowered = text.lowercased()

        // --- 用户画像提取 ---

        // 名字
        let namePatterns = ["我叫", "我的名字是", "叫我", "我是", "称呼我"]
        for pattern in namePatterns {
            if let range = text.range(of: pattern) {
                let afterPattern = String(text[range.upperBound...])
                let name = extractFirstSegment(afterPattern, maxLength: 10)
                if !name.isEmpty, name.count <= 8 {
                    updateProfile("称呼", value: name)
                }
            }
        }

        // 年龄
        if let ageMatch = text.range(of: "我(今年)?\\s*\\d{1,3}\\s*岁", options: .regularExpression) {
            let ageStr = String(text[ageMatch])
            updateProfile("年龄", value: ageStr)
        }

        // 职业
        let jobPatterns = ["我是做", "我的工作是", "我的职业是", "我在做", "我是一个", "我是一名"]
        for pattern in jobPatterns {
            if let range = text.range(of: pattern) {
                let afterPattern = String(text[range.upperBound...])
                let job = extractFirstSegment(afterPattern, maxLength: 15)
                if !job.isEmpty {
                    updateProfile("职业", value: job)
                }
            }
        }

        // 地点
        let locationPatterns = ["我在", "我住在", "我住", "我是.*人"]
        for pattern in locationPatterns {
            if let range = text.range(of: pattern, options: .regularExpression) {
                let afterPattern = String(text[range.upperBound...])
                let location = extractFirstSegment(afterPattern, maxLength: 10)
                if !location.isEmpty, location.count >= 2 {
                    updateProfile("所在地", value: location)
                }
            }
        }

        // --- 兴趣爱好提取 ---
        let hobbyPatterns = ["我喜欢", "我爱", "我最喜欢", "我的爱好是", "我的兴趣是"]
        for pattern in hobbyPatterns {
            if let range = text.range(of: pattern) {
                let afterPattern = String(text[range.upperBound...])
                let hobby = extractFirstSegment(afterPattern, maxLength: 20)
                if !hobby.isEmpty {
                    addFact("主人喜欢\(hobby)", category: .preference, timestamp: timestamp)
                }
            }
        }

        // --- 重要事实提取 ---
        let factPatterns = ["我有一", "我养了", "我家", "我的.*叫", "我今天", "我明天", "我昨天"]
        for pattern in factPatterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                // 整句作为事实记忆（截取前40字）
                let fact = String(text.prefix(40))
                addFact(fact, category: .fact, timestamp: timestamp)
            }
        }

        // --- 情感记忆 ---
        let emotionMap: [(patterns: [String], emotion: String)] = [
            (["开心", "高兴", "太好了", "哈哈", "嘻嘻", "好棒"], "开心"),
            (["难过", "伤心", "不开心", "郁闷", "心情不好", "烦"], "难过"),
            (["生气", "气死", "讨厌", "烦死"], "生气"),
            (["累", "好累", "疲惫", "困了", "好困"], "疲惫"),
            (["无聊", "好无聊", "没意思"], "无聊"),
            (["害怕", "好怕", "紧张", "焦虑"], "焦虑"),
        ]
        for (patterns, emotion) in emotionMap {
            if patterns.contains(where: { lowered.contains($0) }) {
                addEmotionalMemory(
                    content: String(text.prefix(30)),
                    emotion: emotion,
                    timestamp: timestamp
                )
                break
            }
        }

        // --- 话题提取（加入本次会话话题列表）---
        let topicKeywords = ["聊聊", "说说", "讲讲", "告诉我", "知道", "什么是", "怎么"]
        for keyword in topicKeywords {
            if let range = text.range(of: keyword) {
                let afterKeyword = String(text[range.upperBound...])
                let topic = extractFirstSegment(afterKeyword, maxLength: 10)
                if !topic.isEmpty, !sessionTopics.contains(topic) {
                    sessionTopics.append(topic)
                    if sessionTopics.count > 10 {
                        sessionTopics.removeFirst()
                    }
                }
            }
        }
    }

    // MARK: - 会话结束处理

    /// app 退出或长时间不聊天时调用，保存会话摘要
    func endSession(messages: [ChatMessage]) {
        guard enabled, messages.count >= 2 else { return }

        updateSessionSummary(from: messages)

        // 把本次会话摘要存入长期记忆
        if !sessionSummary.isEmpty {
            let summary = SessionSummary(
                date: Date(),
                summary: sessionSummary,
                topics: sessionTopics,
                messageCount: messages.count
            )
            longTermMemory.sessionSummaries.append(summary)

            // 最多保留 20 条会话摘要
            if longTermMemory.sessionSummaries.count > 20 {
                longTermMemory.sessionSummaries.removeFirst(longTermMemory.sessionSummaries.count - 20)
            }
        }

        save()

        // 重置会话状态
        sessionTopics = []
        sessionSummary = ""
        sessionMessageCount = 0
    }

    // MARK: - 会话摘要生成（轻量级，基于规则）

    private func updateSessionSummary(from messages: [ChatMessage]) {
        let userMessages = messages.filter { $0.role == .user }
        guard !userMessages.isEmpty else { return }

        // 简单摘要：列出用户聊过的关键内容
        let topics = userMessages.suffix(6).map { msg -> String in
            let text = msg.content
            if text.count <= 15 {
                return text
            }
            return String(text.prefix(15)) + "..."
        }

        sessionSummary = "聊了：" + topics.joined(separator: "；")
    }

    // MARK: - 长期记忆操作

    private func updateProfile(_ key: String, value: String) {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "，", with: "")
            .replacingOccurrences(of: "。", with: "")
            .replacingOccurrences(of: "的", with: "")
        guard !cleaned.isEmpty, cleaned.count <= 20 else { return }

        if longTermMemory.userProfile[key] != cleaned {
            longTermMemory.userProfile[key] = cleaned
            NSLog("[Memory] 更新用户画像: \(key) = \(cleaned)")
            save()
        }
    }

    private func addFact(_ content: String, category: MemoryEntry.Category, timestamp: Date) {
        // 去重：如果已有相似内容，不重复添加
        let isDuplicate = longTermMemory.facts.contains { existing in
            existing.content == content ||
            (existing.content.count > 5 && content.contains(existing.content)) ||
            (content.count > 5 && existing.content.contains(content))
        }
        guard !isDuplicate else { return }

        let entry = MemoryEntry(
            content: content,
            category: category,
            timestamp: timestamp
        )
        longTermMemory.facts.append(entry)

        // 最多保留 50 条事实
        if longTermMemory.facts.count > 50 {
            longTermMemory.facts.removeFirst()
        }

        NSLog("[Memory] 新增事实记忆: \(content)")
        save()
    }

    private func addEmotionalMemory(content: String, emotion: String, timestamp: Date) {
        let entry = EmotionalMemory(content: content, emotion: emotion, timestamp: timestamp)
        longTermMemory.emotionalMemories.append(entry)

        // 最多保留 20 条情感记忆
        if longTermMemory.emotionalMemories.count > 20 {
            longTermMemory.emotionalMemories.removeFirst()
        }

        NSLog("[Memory] 新增情感记忆: \(emotion) - \(content)")
        save()
    }

    // MARK: - 清空记忆

    /// 清空所有长期记忆
    func clearAllMemory() {
        longTermMemory = LongTermMemory()
        sessionTopics = []
        sessionSummary = ""
        sessionMessageCount = 0
        save()
        NSLog("[Memory] 所有记忆已清空")
    }

    /// 只清空长期记忆
    func clearLongTermMemory() {
        longTermMemory = LongTermMemory()
        save()
        NSLog("[Memory] 长期记忆已清空")
    }

    // MARK: - 持久化

    private static let storageKey = "com.luoxiaohei.pet.longTermMemory"

    private func save() {
        if let data = try? JSONEncoder().encode(longTermMemory) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    // MARK: - Helpers

    /// 提取第一个有效文本段（到标点或空格为止）
    private func extractFirstSegment(_ text: String, maxLength: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let delimiters = CharacterSet(charactersIn: "，。！？、；：\n,.!?;: ")
        let segment = trimmed.components(separatedBy: delimiters).first ?? ""
        return String(segment.prefix(maxLength))
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M月d日"
        return f
    }()
}

// MARK: - 数据模型

/// 长期记忆（持久化存储）
struct LongTermMemory: Codable {
    /// 用户画像：称呼、年龄、职业、所在地等
    var userProfile: [String: String] = [:]

    /// 事实记忆：用户提到的重要信息
    var facts: [MemoryEntry] = []

    /// 情感记忆：用户的情绪状态历史
    var emotionalMemories: [EmotionalMemory] = []

    /// 历史会话摘要
    var sessionSummaries: [SessionSummary] = []

    static func load() -> LongTermMemory {
        let key = "com.luoxiaohei.pet.longTermMemory"
        guard let data = UserDefaults.standard.data(forKey: key),
              let memory = try? JSONDecoder().decode(LongTermMemory.self, from: data) else {
            return LongTermMemory()
        }
        return memory
    }
}

/// 单条记忆条目
struct MemoryEntry: Codable {
    let content: String
    let category: Category
    let timestamp: Date

    enum Category: String, Codable {
        case fact        // 事实（"主人养了一只猫"）
        case preference  // 偏好（"主人喜欢红色"）
        case event       // 事件（"主人今天考试"）
    }
}

/// 情感记忆条目
struct EmotionalMemory: Codable {
    let content: String
    let emotion: String  // 开心、难过、生气等
    let timestamp: Date
}

/// 会话摘要
struct SessionSummary: Codable {
    let date: Date
    let summary: String
    let topics: [String]
    let messageCount: Int
}
