import Cocoa

/// 动画引擎 —— 管理帧序列加载、播放、状态切换
class AnimationEngine {

    // MARK: - Callbacks
    /// 每帧更新时回调，传递当前帧图片
    var onFrameUpdate: ((NSImage) -> Void)?
    /// 状态变化时回调
    var onStateChange: ((PetAnimationState) -> Void)?

    // MARK: - State
    private(set) var currentState: PetAnimationState? = nil
    private var currentFrames: [NSImage] = []
    private var currentFrameIndex: Int = 0
    private var timer: Timer?
    private var nextState: PetAnimationState?

    // MARK: - Cache
    /// 缓存已加载的动画帧，避免重复读取磁盘
    private var frameCache: [PetAnimationState: [NSImage]] = [:]

    // MARK: - Auto Behavior
    /// 自动行为定时器（待机时随机播放小动作）
    private var autoBehaviorTimer: Timer?
    private let autoBehaviorInterval: TimeInterval = 15.0 // 15秒触发一次随机行为

    // MARK: - Public API

    /// 播放指定动画状态
    /// - Parameters:
    ///   - state: 目标动画状态
    ///   - then: 播放完成后过渡到的状态（仅对非循环动画有效）
    func play(state: PetAnimationState, then nextState: PetAnimationState? = nil) {
        if let current = currentState, state == current, state.isLooping { return }

        self.currentState = state
        self.nextState = nextState ?? state.defaultTransition
        self.currentFrameIndex = 0

        onStateChange?(state)
        loadFrames(for: state)
        startPlayback()

        // 管理自动行为
        if state == .idle {
            startAutoBehavior()
        } else {
            stopAutoBehavior()
        }
    }

    /// 停止所有动画
    func stop() {
        timer?.invalidate()
        timer = nil
        stopAutoBehavior()
    }

    /// 处理状态机事件
    func handleEvent(_ event: AnimationEvent) {
        switch event {
        case .click:
            let reactions: [PetAnimationState] = [.happy, .stretch, .lookAround]
            if let reaction = reactions.randomElement() {
                play(state: reaction, then: .idle)
            }

        case .startDrag:
            play(state: .drag)

        case .endDrag:
            play(state: .fall, then: .idle)

        case .startChat:
            play(state: .talking)

        case .endChat:
            play(state: .idle)

        case .llmThinking:
            play(state: .thinking)

        case .llmResponded:
            play(state: .talking)

        case .timer:
            // 自动行为：随机选一个小动作
            let behaviors: [PetAnimationState] = [.stretch, .lookAround, .walk]
            if let behavior = behaviors.randomElement() {
                play(state: behavior, then: .idle)
            }

        case .doubleClick:
            break // 由 ViewController 处理
        }
    }

    // MARK: - Frame Loading

    private func loadFrames(for state: PetAnimationState) {
        // 先检查缓存
        if let cached = frameCache[state], !cached.isEmpty {
            currentFrames = cached
            return
        }

        // 从 bundle 加载 {state}_{NNN}.png 扁平命名帧
        let bundle = Bundle.main
        let prefix = state.folderName
        var frames: [NSImage] = []

        // 按序号尝试加载帧（最多100帧）
        for i in 0..<100 {
            let name = String(format: "%@_%03d", prefix, i)
            if let image = bundle.image(forResource: name) {
                frames.append(image)
            } else {
                break // 序号不连续时停止
            }
        }

        if frames.isEmpty {
            NSLog("[AnimationEngine] 动画帧不存在: \(prefix)_*，使用占位帧")
            loadPlaceholderFrames()
        } else {
            currentFrames = frames
            frameCache[state] = frames
        }
    }

    /// 加载 GIF 文件作为帧序列
    func loadGIF(named name: String, for state: PetAnimationState) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "gif"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            NSLog("[AnimationEngine] 无法加载 GIF: \(name)")
            return
        }

        let frameCount = CGImageSourceGetCount(source)
        var frames: [NSImage] = []

        for i in 0..<frameCount {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(
                    width: cgImage.width,
                    height: cgImage.height
                ))
                frames.append(nsImage)
            }
        }

        frameCache[state] = frames
        if currentState == state {
            currentFrames = frames
        }
    }

    // MARK: - Playback

    private func startPlayback() {
        timer?.invalidate()

        guard !currentFrames.isEmpty else { return }

        // 立即显示第一帧
        onFrameUpdate?(currentFrames[0])

        timer = Timer.scheduledTimer(withTimeInterval: currentState?.frameDuration ?? 0.15, repeats: true) {
            [weak self] _ in
            self?.advanceFrame()
        }
    }

    private func advanceFrame() {
        currentFrameIndex += 1

        if currentFrameIndex >= currentFrames.count {
            if currentState?.isLooping == true {
                // 循环播放：回到第一帧
                currentFrameIndex = 0
            } else {
                // 非循环：过渡到下一个状态
                timer?.invalidate()
                if let next = nextState {
                    play(state: next)
                }
                return
            }
        }

        onFrameUpdate?(currentFrames[currentFrameIndex])
    }

    // MARK: - Auto Behavior

    private func startAutoBehavior() {
        stopAutoBehavior()
        autoBehaviorTimer = Timer.scheduledTimer(withTimeInterval: autoBehaviorInterval, repeats: true) {
            [weak self] _ in
            // 有一定概率触发随机行为
            if Double.random(in: 0...1) < 0.4 {
                self?.handleEvent(.timer)
            }
        }
    }

    private func stopAutoBehavior() {
        autoBehaviorTimer?.invalidate()
        autoBehaviorTimer = nil
    }

    // MARK: - Placeholder

    /// 生成占位帧（开发阶段没有素材时使用）
    private func loadPlaceholderFrames() {
        let size = NSSize(width: 128, height: 128)
        let image = NSImage(size: size, flipped: false) { rect in
            // 画一个简单的黑猫剪影作为占位
            NSColor.black.setFill()

            // 身体（椭圆）
            let bodyRect = NSRect(x: 30, y: 10, width: 68, height: 60)
            let body = NSBezierPath(ovalIn: bodyRect)
            body.fill()

            // 头（圆）
            let headRect = NSRect(x: 38, y: 55, width: 52, height: 50)
            let head = NSBezierPath(ovalIn: headRect)
            head.fill()

            // 耳朵（三角形）
            let leftEar = NSBezierPath()
            leftEar.move(to: NSPoint(x: 42, y: 95))
            leftEar.line(to: NSPoint(x: 32, y: 115))
            leftEar.line(to: NSPoint(x: 55, y: 100))
            leftEar.close()
            leftEar.fill()

            let rightEar = NSBezierPath()
            rightEar.move(to: NSPoint(x: 86, y: 95))
            rightEar.line(to: NSPoint(x: 96, y: 115))
            rightEar.line(to: NSPoint(x: 73, y: 100))
            rightEar.close()
            rightEar.fill()

            // 眼睛（绿色）
            NSColor(red: 0.2, green: 0.9, blue: 0.4, alpha: 1.0).setFill()
            NSBezierPath(ovalIn: NSRect(x: 48, y: 70, width: 12, height: 14)).fill()
            NSBezierPath(ovalIn: NSRect(x: 68, y: 70, width: 12, height: 14)).fill()

            return true
        }

        currentFrames = [image]
    }
}
