import Cocoa

/// 系统托盘（菜单栏）控制器
class StatusBarController {

    // MARK: - Properties
    private var statusItem: NSStatusItem!
    private let onTogglePet: () -> Void
    private let onOpenSettings: () -> Void
    private let onQuit: () -> Void

    // MARK: - Init
    init(onTogglePet: @escaping () -> Void,
         onOpenSettings: @escaping () -> Void,
         onQuit: @escaping () -> Void) {
        self.onTogglePet = onTogglePet
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit

        setupStatusItem()
    }

    // MARK: - Setup
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            // 使用 SF Symbol 作为菜单栏图标（也可以换成自定义的小黑猫图标）
            if let image = NSImage(systemSymbolName: "cat.fill", accessibilityDescription: "罗小黑") {
                image.isTemplate = true  // 自动适配深色/浅色模式
                button.image = image
            } else {
                button.title = "🐱"
            }
            button.toolTip = "罗小黑桌宠"
        }

        setupMenu()
    }

    private func setupMenu() {
        let menu = NSMenu()

        menu.addItem(withTitle: "显示/隐藏小黑",
                     action: #selector(togglePet),
                     keyEquivalent: "h")
            .target = self

        menu.addItem(.separator())

        menu.addItem(withTitle: "设置...",
                     action: #selector(openSettings),
                     keyEquivalent: ",")
            .target = self

        menu.addItem(.separator())

        // 关于
        menu.addItem(withTitle: "关于罗小黑桌宠",
                     action: #selector(showAbout),
                     keyEquivalent: "")
            .target = self

        menu.addItem(.separator())

        menu.addItem(withTitle: "退出",
                     action: #selector(quit),
                     keyEquivalent: "q")
            .target = self

        statusItem.menu = menu
    }

    // MARK: - Actions
    @objc private func togglePet() { onTogglePet() }
    @objc private func openSettings() { onOpenSettings() }
    @objc private func quit() { onQuit() }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "罗小黑桌宠"
        alert.informativeText = """
        一只住在你桌面上的小黑猫 🐱

        版本 1.0.0
        基于火山引擎大模型 API
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好的喵~")
        alert.runModal()
    }
}
