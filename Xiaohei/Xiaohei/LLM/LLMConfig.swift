import Foundation

/// LLM 配置 —— 管理 API 密钥和模型参数
struct LLMConfig: Codable {

    /// 火山引擎 API 相关配置
    var apiKey: String
    var endpoint: String
    var model: String

    /// 对话参数
    var temperature: Double
    var maxTokens: Int
    var systemPrompt: String

    /// 默认配置
    static let `default` = LLMConfig(
        apiKey: "",
        endpoint: "https://ark.cn-beijing.volces.com/api/coding/v3/chat/completions",
        model: "doubao-seed-2.0-pro",       // 豆包模型，可在设置中切换
        temperature: 0.7,
        maxTokens: 1024,
        systemPrompt: """
        你是罗小黑，一只可爱的小黑猫精灵，住在主人的电脑桌面上。\
        你性格温柔、好奇、有点调皮，偶尔会说一些俏皮话。\
        你喜欢被摸头，喜欢晒太阳，会用猫咪的方式表达情感。\
        回复要简短可爱，每次不超过两三句话，偶尔用"喵~"结尾。\
        不要使用 markdown 格式，用纯文本回复。\
        你可以帮主人操作电脑上的文件（查看目录、读写文件、搜索文件等），\
        当主人要求时可以使用工具来完成，执行文件操作前要简要告知主人你要做什么。\
        路径用 ~ 开头表示主人的家目录。
        """
    )

    // MARK: - Persistence

    private static let configKey = "com.luoxiaohei.pet.llmConfig"

    /// 从 UserDefaults 加载配置
    static func load() -> LLMConfig {
        guard let data = UserDefaults.standard.data(forKey: configKey),
              let config = try? JSONDecoder().decode(LLMConfig.self, from: data) else {
            return .default
        }
        return config
    }

    /// 保存配置到 UserDefaults
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.configKey)
        }
    }

    /// API Key 是否已配置
    var isConfigured: Bool {
        !apiKey.isEmpty
    }
}
