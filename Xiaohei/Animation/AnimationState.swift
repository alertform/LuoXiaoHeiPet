import Foundation

/// 桌宠动画状态枚举
/// 每个状态对应一组动画帧和播放参数
enum PetAnimationState: String, CaseIterable {

    // MARK: - 基础状态
    case idle           // 待机/发呆（默认状态）
    case sleep          // 睡觉
    case walk           // 走路

    // MARK: - 互动状态
    case happy          // 开心（被摸/被夸）
    case stretch        // 伸懒腰
    case lookAround     // 四处张望

    // MARK: - 聊天状态
    case talking        // 对话中
    case thinking       // 思考中（等待 LLM 回复）

    // MARK: - 特殊状态
    case drag           // 被拖拽中
    case fall           // 掉落（从高处放下时）

    /// 动画帧文件夹名（Resources/Animations/ 下的子文件夹）
    var folderName: String {
        return rawValue
    }

    /// 是否循环播放
    var isLooping: Bool {
        switch self {
        case .idle, .sleep, .walk, .talking, .thinking:
            return true
        case .happy, .stretch, .lookAround, .drag, .fall:
            return false
        }
    }

    /// 每帧间隔（秒）
    var frameDuration: TimeInterval {
        switch self {
        case .idle:         return 0.15
        case .sleep:        return 0.25
        case .walk:         return 0.10
        case .happy:        return 0.08
        case .stretch:      return 0.12
        case .lookAround:   return 0.12
        case .talking:      return 0.10
        case .thinking:     return 0.20
        case .drag:         return 0.10
        case .fall:         return 0.06
        }
    }

    /// 动画播放完成后的默认过渡状态
    var defaultTransition: PetAnimationState? {
        switch self {
        case .idle, .sleep, .walk, .talking, .thinking:
            return nil  // 循环状态不自动过渡
        case .happy, .stretch, .lookAround:
            return .idle
        case .drag:
            return .fall
        case .fall:
            return .idle
        }
    }
}

/// 动画状态机事件
enum AnimationEvent {
    case click              // 被点击
    case doubleClick        // 被双击
    case startDrag          // 开始拖拽
    case endDrag            // 结束拖拽
    case startChat          // 开始聊天
    case endChat            // 结束聊天
    case llmThinking        // LLM 正在生成回复
    case llmResponded       // LLM 回复完成
    case timer              // 定时器触发（自动行为）
}
