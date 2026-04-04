//
//  XiaoheiApp.swift
//  Xiaohei
//
//  Created by bbnomoney on 2026/4/1.
//

import Cocoa

@main
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    // 静态强引用，防止被 ARC 释放
    private static var _shared: AppDelegate!

    // MARK: - Properties
    private var petWindow: PetWindow!
    private var statusBarController: StatusBarController!
    private var chatManager: ChatManager!
    private var animationEngine: AnimationEngine!

    // 显式 main 入口
    nonisolated static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        AppDelegate._shared = delegate  // 保持强引用
        app.delegate = delegate
        app.run()
    }

    // MARK: - App Lifecycle
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupServices()
        setupPetWindow()
        setupStatusBar()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(llmConfigChanged(_:)),
            name: .llmConfigDidChange,
            object: nil
        )

        // 添加标准 Edit 菜单（支持复制粘贴）
        setupEditMenu()

        NSLog("[Xiaohei] 罗小黑桌宠启动完成 ✨")
    }

    private func setupEditMenu() {
        let mainMenu = NSMenu()

        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = {
            let menu = NSMenu(title: "Edit")
            menu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
            menu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
            menu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
            menu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
            return menu
        }()
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    func applicationWillTerminate(_ notification: Notification) {
        animationEngine.stop()
        chatManager.endSession()  // 保存历史 + 会话记忆
        NSLog("[Xiaohei] 桌宠已退出")
    }

    // MARK: - Setup
    private func setupServices() {
        let llmConfig = LLMConfig.load()
        let llmService = VolcanoEngineService(config: llmConfig)
        chatManager = ChatManager(llmService: llmService)
        animationEngine = AnimationEngine()

        // 加载记忆系统配置
        MemoryManager.shared.enabled = UserDefaults.standard.object(forKey: "memory.enabled") as? Bool ?? true
    }

    private func setupPetWindow() {
        petWindow = PetWindow()

        let petViewController = PetViewController(
            animationEngine: animationEngine,
            chatManager: chatManager
        )
        petWindow.contentViewController = petViewController
        petWindow.makeKeyAndOrderFront(nil)

        animationEngine.play(state: .idle)
    }

    private func setupStatusBar() {
        statusBarController = StatusBarController(
            onTogglePet: { [weak self] in
                self?.togglePetVisibility()
            },
            onOpenSettings: { [weak self] in
                self?.openSettings()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
    }

    // MARK: - Actions
    private func togglePetVisibility() {
        if petWindow.isVisible {
            petWindow.orderOut(nil)
        } else {
            petWindow.makeKeyAndOrderFront(nil)
        }
    }

    private func openSettings() {
        SettingsWindow.shared.showWindow(nil)
    }

    @objc private func llmConfigChanged(_ notification: Notification) {
        // 重新加载 LLM 配置
        let newConfig = LLMConfig.load()
        let newService = VolcanoEngineService(config: newConfig)
        chatManager.updateLLMService(newService)

        // 更新 TTS 配置
        chatManager.ttsService.enabled = UserDefaults.standard.object(forKey: "tts.enabled") as? Bool ?? true
        chatManager.ttsService.voiceType = UserDefaults.standard.string(forKey: "tts.voiceType") ?? "BV051_streaming"

        // 更新记忆配置
        MemoryManager.shared.enabled = UserDefaults.standard.object(forKey: "memory.enabled") as? Bool ?? true

        NSLog("[Xiaohei] 配置已更新, endpoint=\(newConfig.endpoint), model=\(newConfig.model), tts=\(chatManager.ttsService.enabled), memory=\(MemoryManager.shared.enabled)")
    }
}
