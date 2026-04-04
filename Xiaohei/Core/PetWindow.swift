import Cocoa

/// 桌宠主窗口 —— 透明、无边框、置顶、可拖拽
class PetWindow: NSWindow {

    // MARK: - Constants
    private static let defaultSize = NSSize(width: 128, height: 128)

    // MARK: - Init
    init() {
        // 初始位置：屏幕右下角偏上
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let origin = NSPoint(
            x: screenFrame.maxX - Self.defaultSize.width - 60,
            y: screenFrame.minY + 80
        )
        let frame = NSRect(origin: origin, size: Self.defaultSize)

        super.init(
            contentRect: frame,
            styleMask: [.borderless],       // 无边框
            backing: .buffered,
            defer: false
        )

        configureWindow()
    }

    // MARK: - Configuration
    private func configureWindow() {
        // 透明背景
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false

        // 始终置顶（在所有窗口之上）
        level = .statusBar

        // 允许在所有桌面空间显示
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        // 不在 Expose/Mission Control 中显示
        isExcludedFromWindowsMenu = true

        // 允许鼠标事件穿透透明区域
        ignoresMouseEvents = false
        isMovableByWindowBackground = true

        // 窗口关闭不释放（桌宠常驻）
        isReleasedWhenClosed = false
    }

    // MARK: - Dragging Support
    // 使整个窗口内容区域都可以拖拽
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
