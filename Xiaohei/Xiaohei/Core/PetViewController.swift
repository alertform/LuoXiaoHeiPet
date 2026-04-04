import Cocoa

/// 桌宠主控制器 —— 协调动画显示与用户交互
class PetViewController: NSViewController {

    // MARK: - Dependencies
    private let animationEngine: AnimationEngine
    private let chatManager: ChatManager

    // MARK: - UI Components
    private var petView: PetView!
    private var chatBubbleWindow: ChatBubbleWindow?

    // MARK: - State
    private var isDragging = false
    private var dragStartLocation: NSPoint = .zero
    private var lastClickTime: Date?
    private let doubleClickInterval: TimeInterval = 0.3

    // MARK: - Init
    init(animationEngine: AnimationEngine, chatManager: ChatManager) {
        self.animationEngine = animationEngine
        self.chatManager = chatManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func loadView() {
        petView = PetView(frame: NSRect(origin: .zero, size: NSSize(width: 128, height: 128)))
        self.view = petView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        animationEngine.onFrameUpdate = { [weak self] image in
            self?.petView.currentFrame = image
        }

        setupContextMenu()
    }

    // MARK: - Mouse Events
    override func mouseDown(with event: NSEvent) {
        isDragging = false
        dragStartLocation = event.locationInWindow
        lastClickTime = Date()
    }

    override func mouseDragged(with event: NSEvent) {
        let dx = event.locationInWindow.x - dragStartLocation.x
        let dy = event.locationInWindow.y - dragStartLocation.y
        if abs(dx) > 3 || abs(dy) > 3 {
            if !isDragging {
                isDragging = true
                // 开始拖动 → 关闭聊天气泡
                if chatBubbleWindow != nil {
                    closeChatBubble()
                }
            }
            // 移动窗口
            guard let window = view.window else { return }
            var origin = window.frame.origin
            origin.x += dx
            origin.y += dy
            window.setFrameOrigin(origin)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if isDragging {
            isDragging = false
            return
        }

        // 点击处理
        let now = Date()
        if let lastClick = lastClickTime,
           now.timeIntervalSince(lastClick) < doubleClickInterval {
            // 这是第二次点击 → 双击
            // 由于 mouseDown 也更新了 lastClickTime，需要检测间隔
        }

        // 用简单的双击检测
        if event.clickCount == 2 {
            handleDoubleClick()
        } else if event.clickCount == 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self, !self.isDragging else { return }
                self.handleSingleClick()
            }
        }
    }

    private func handleSingleClick() {
        let interactionStates: [PetAnimationState] = [.happy, .stretch, .lookAround]
        if let randomState = interactionStates.randomElement() {
            animationEngine.play(state: randomState, then: .idle)
        }
    }

    private func handleDoubleClick() {
        toggleChatBubble()
    }

    // MARK: - Chat Bubble
    private func toggleChatBubble() {
        if let bubble = chatBubbleWindow, bubble.isVisible {
            closeChatBubble()
        } else {
            openChatBubble()
        }
    }

    private func openChatBubble() {
        guard let petWindow = view.window else { return }

        let petFrame = petWindow.frame
        let bubbleOrigin = NSPoint(
            x: petFrame.midX - 130,
            y: petFrame.maxY + 8
        )

        // 关闭旧的（清理回调）
        closeChatBubble()

        chatBubbleWindow = ChatBubbleWindow(
            origin: bubbleOrigin,
            chatManager: chatManager,
            onClose: { [weak self] in
                self?.closeChatBubble()
            }
        )
        chatBubbleWindow?.makeKeyAndOrderFront(nil)
        animationEngine.play(state: .talking)
    }

    private func closeChatBubble() {
        chatBubbleWindow?.cleanup()
        chatBubbleWindow?.close()
        chatBubbleWindow = nil
        animationEngine.play(state: .idle)
    }

    // MARK: - Context Menu
    private func setupContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "聊天", action: #selector(menuChat), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "开心", action: #selector(menuHappy), keyEquivalent: "")
        menu.addItem(withTitle: "睡觉", action: #selector(menuSleep), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "设置", action: #selector(menuSettings), keyEquivalent: ",")
        petView.menu = menu
    }

    @objc private func menuChat() { toggleChatBubble() }
    @objc private func menuHappy() { animationEngine.play(state: .happy, then: .idle) }
    @objc private func menuSleep() { animationEngine.play(state: .sleep) }
    @objc private func menuSettings() { SettingsWindow.shared.showWindow(nil) }
}
