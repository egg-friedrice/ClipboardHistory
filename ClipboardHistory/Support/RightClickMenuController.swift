import AppKit

/// 由自己的 NSStatusItem 右键事件触发，避免拦截其他菜单栏图标。
final class RightClickMenuController {

    private weak var store: ClipboardStore?
    private weak var autoLaunch: AutoLaunchService?
    private weak var accessibility: AccessibilityService?

    /// 回调闭包，由 App 层注入。
    var onPreferences: (() -> Void)?
    var onAbout: (() -> Void)?

    /// 注入依赖并启动监听。
    func configure(store: ClipboardStore,
                   autoLaunch: AutoLaunchService,
                   accessibility: AccessibilityService,
                   onPreferences: @escaping () -> Void,
                   onAbout: @escaping () -> Void) {
        self.store = store
        self.autoLaunch = autoLaunch
        self.accessibility = accessibility
        self.onPreferences = onPreferences
        self.onAbout = onAbout

    }

    /// 交给状态栏原生菜单布局，避免普通弹出菜单在屏幕顶部裁切。
    func showMenu(relativeTo statusItem: NSStatusItem?) {
        guard let statusItem, let button = statusItem.button else { return }
        accessibility?.refresh()
        let menu = buildMenu()
        statusItem.menu = menu
        defer { statusItem.menu = nil }
        // 菜单跟踪结束后恢复自定义点击动作，左键仍打开历史面板。
        button.performClick(nil)
    }

    /// 构建 NSMenu（contract S06 顺序严格）。
    func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.minimumWidth = 200
        // 状态按钮的外观可能随壁纸变化；菜单应跟随应用的系统外观。
        menu.appearance = NSApp.effectiveAppearance

        // 1. 暂停监听 (toggle)
        let pauseItem = NSMenuItem(title: "暂停监听", action: #selector(togglePause(_:)), keyEquivalent: "")
        pauseItem.target = self
        pauseItem.state = (store?.isPaused ?? false) ? .on : .off
        menu.addItem(pauseItem)

        // 2. 偏好设置…
        let prefsItem = NSMenuItem(title: "设置…", action: #selector(openPreferences(_:)), keyEquivalent: "")
        prefsItem.target = self
        menu.addItem(prefsItem)

        // 3. 开机自启动 (toggle)
        let launchItem = NSMenuItem(title: "开机自启动", action: #selector(toggleAutoLaunch(_:)), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = (autoLaunch?.isEnabled ?? false) ? .on : .off
        menu.addItem(launchItem)

        // 4. 辅助功能…（已授权 / 未授权）
        let axStatus = accessibility?.isTrusted ?? false
        let axTitle = "辅助功能…（\(axStatus ? "已授权" : "未授权")）"
        let axItem = NSMenuItem(title: axTitle, action: #selector(openAccessibility(_:)), keyEquivalent: "")
        axItem.target = self
        menu.addItem(axItem)

        // 5. 分隔线
        menu.addItem(.separator())

        // 6. 关于 ClipboardHistory
        let aboutItem = NSMenuItem(title: "关于 ClipboardHistory", action: #selector(openAbout(_:)), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        // 7. 退出 ClipboardHistory  ⌘Q
        let quitItem = NSMenuItem(title: "退出 ClipboardHistory", action: #selector(quitApp(_:)), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = .command
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    // MARK: - Actions

    @objc private func togglePause(_ sender: Any?) {
        store?.isPaused.toggle()
    }

    @objc private func openPreferences(_ sender: Any?) {
        onPreferences?()
    }

    @objc private func toggleAutoLaunch(_ sender: Any?) {
        guard let autoLaunch = autoLaunch else { return }
        autoLaunch.setEnabled(!autoLaunch.isEnabled)
    }

    @objc private func openAccessibility(_ sender: Any?) {
        accessibility?.openSystemSettings()
    }

    @objc private func openAbout(_ sender: Any?) {
        onAbout?()
    }

    @objc private func quitApp(_ sender: Any?) {
        // NSMenu.popUp 在 modal runloop 中阻塞，terminate 需延迟到 popUp 返回后执行。
        DispatchQueue.main.async {
            NSApplication.shared.terminate(nil)
        }
    }
}
