import AppKit
import SwiftUI

/// 右键菜单触发窗口打开的通知名。
extension Notification.Name {
    static let openPreferencesFromMenu = Notification.Name("clipboard.openPreferencesFromMenu")
    static let openAboutFromMenu = Notification.Name("clipboard.openAboutFromMenu")
}

/// AppKit 生命周期管理菜单栏与窗口，SwiftUI 仅负责窗口内的界面。
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, ObservableObject {

    // 核心服务对象（强持有）。
    let store = ClipboardStore()
    let hotkey = GlobalHotkey()
    let autoLaunch = AutoLaunchService()
    let accessibility = AccessibilityService()
    let scanner = ExpirationScanner()
    let rightClickMenu = RightClickMenuController()
    let imagePreviews = ImagePreviewController()

    private(set) var statusItem: NSStatusItem?
    private let historyPopover = NSPopover()
    private var appearanceObservation: NSKeyValueObservation?

    /// 持有偏好设置窗口，避免被释放。
    private var preferencesWindow: NSWindow?
    /// 持有关于窗口。
    private var aboutWindow: NSWindow?

    private let hotkeyModifiersKey = "clipboard.hotkey.modifiers"
    private let hotkeyKeyCodeKey = "clipboard.hotkey.keyCode"
    private let defaultModifiers: NSEvent.ModifierFlags = [.command, .shift]
    private let defaultKeyCode: UInt32 = 9

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMainMenu()
        setupHistoryPanel()
        setupHotkey()
        setupScanner()
        setupAutoLaunch()
        setupRightClickMenu()
        NSLog("[AppDelegate] started; status item visible=%d", statusItem?.isVisible == true)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        accessibility.refresh()
    }

    // MARK: - Setup

    private func setupMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        let settings = appMenu.addItem(withTitle: "设置…", action: #selector(showPreferences(_:)), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出 ClipboardHistory",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }

    private func setupHotkey() {
        guard !hotkey.isRegistered else { return }
        let savedModsRaw = UserDefaults.standard.integer(forKey: hotkeyModifiersKey)
        let savedKeyCode = UserDefaults.standard.integer(forKey: hotkeyKeyCodeKey)
        let modifiers: NSEvent.ModifierFlags = savedModsRaw == 0
            ? defaultModifiers
            : NSEvent.ModifierFlags(rawValue: UInt(savedModsRaw))
        let keyCode = UserDefaults.standard.object(forKey: hotkeyKeyCodeKey) == nil
            ? defaultKeyCode : UInt32(clamping: savedKeyCode)

        let ok = hotkey.register(modifiers: modifiers, keyCode: keyCode)
        if !ok {
            NSLog("[AppDelegate] hotkey register failed, falling back to default")
            _ = hotkey.register(modifiers: defaultModifiers, keyCode: defaultKeyCode)
            UserDefaults.standard.set(Int(defaultModifiers.rawValue), forKey: hotkeyModifiersKey)
            UserDefaults.standard.set(Int(defaultKeyCode), forKey: hotkeyKeyCodeKey)
        }

        hotkey.onTrigger = { [weak self] in
            self?.handleHotkeyTrigger()
        }
    }

    private func setupScanner() {
        scanner.store = store
        store.scanner = scanner
        scanner.start()
        scanner.scanOnce()
    }

    private func setupAutoLaunch() {
        autoLaunch.ensureDefaultEnabled()
    }

    private func setupRightClickMenu() {
        rightClickMenu.configure(
            store: store,
            autoLaunch: autoLaunch,
            accessibility: accessibility,
            onPreferences: { [weak self] in
                DispatchQueue.main.async { self?.openPreferencesWindow() }
            },
            onAbout: { [weak self] in
                DispatchQueue.main.async { self?.openAboutWindow() }
            }
        )
    }

    // MARK: - Hotkey

    private func handleHotkeyTrigger() {
        toggleMenuBarExtraPanel()
    }

    // MARK: - Menu Bar Panel

    func setupHistoryPanel() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item
        item.isVisible = true
        item.behavior = []
        item.button?.image = Self.makeStatusIcon()
        item.button?.imagePosition = .imageOnly
        item.button?.toolTip = "ClipboardHistory · 左键打开历史，右键打开设置"
        item.button?.setAccessibilityLabel("剪贴板历史")
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        historyPopover.behavior = .transient
        historyPopover.animates = false
        historyPopover.contentSize = NSSize(width: 360, height: 480)
        historyPopover.delegate = self
        // 显式使用应用外观，避免继承状态栏按钮的 vibrantDark。
        historyPopover.appearance = NSApp.effectiveAppearance
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] app, _ in
            self?.historyPopover.appearance = app.effectiveAppearance
        }
    }

    /// 固定 18pt 模板图标；不依赖 SF Symbols 名称或彩色图标的暗色适配。
    static func makeStatusIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            let board = NSBezierPath(roundedRect: NSRect(x: 3.5, y: 1.5, width: 11, height: 14),
                                     xRadius: 2, yRadius: 2)
            board.lineWidth = 1.5
            board.stroke()
            NSColor.black.setFill()
            NSBezierPath(roundedRect: NSRect(x: 6, y: 13, width: 6, height: 4),
                         xRadius: 1, yRadius: 1).fill()
            let lines = NSBezierPath()
            for y in [5.0, 8.0, 11.0] {
                lines.move(to: NSPoint(x: 6, y: y))
                lines.line(to: NSPoint(x: 12, y: y))
            }
            lines.lineWidth = 1.2
            lines.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "剪贴板历史"
        return image
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusItem?.isVisible = true
        openPreferencesWindow()
        return true
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            closeHistoryPanel()
            accessibility.refresh()
            NSApp.activate(ignoringOtherApps: true)
            rightClickMenu.showMenu(relativeTo: statusItem?.button)
        } else {
            toggleMenuBarExtraPanel()
        }
    }

    private func toggleMenuBarExtraPanel() {
        if historyPopover.isShown {
            closeHistoryPanel()
            return
        }
        guard let button = statusItem?.button else { return }
        // 必须在面板取得焦点前保存目标。部分编辑器不暴露可写的 AXValue，
        // 因此不以输入框角色检测作为自动粘贴的前置条件。
        accessibility.refresh()
        let target = NSWorkspace.shared.frontmostApplication
        store.pendingPastePID = target?.processIdentifier ?? 0
        store.pendingPasteAfterSelection = accessibility.isTrusted
            && target != nil && target?.processIdentifier != ProcessInfo.processInfo.processIdentifier
        historyPopover.contentViewController = NSHostingController(rootView: ClipboardHistoryView(
            store: store,
            accessibility: accessibility,
            isPresented: Binding(
                get: { [weak self] in self?.historyPopover.isShown ?? false },
                set: { [weak self] shown in if !shown { self?.closeHistoryPanel() } }
            ),
            isHistoryWindow: { [weak self] window in
                guard let window, let self else { return false }
                return window === self.historyPopover.contentViewController?.view.window
            },
            onPreview: { [weak self] item in
                self?.closeHistoryPanel()
                self?.imagePreviews.show(item)
            }
        ))
        historyPopover.appearance = NSApp.effectiveAppearance
        historyPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        historyPopover.contentViewController?.view.window?.makeKey()
    }

    private func closeHistoryPanel() {
        historyPopover.performClose(nil)
        clearPendingPaste()
    }

    func popoverDidClose(_ notification: Notification) {
        clearPendingPaste()
    }

    private func clearPendingPaste() {
        store.pendingPasteAfterSelection = false
        store.pendingPastePID = 0
    }

    // MARK: - Windows

    @objc private func showPreferences(_ sender: Any?) {
        openPreferencesWindow()
    }

    func openPreferencesWindow() {
        // 先关闭可能打开的 MenuBarExtra 面板。
        closeHistoryPanel()
        NSApp.activate(ignoringOtherApps: true)

        // 若窗口已存在则前置。
        if let prefsWindow = preferencesWindow {
            prefsWindow.makeKeyAndOrderFront(nil)
            return
        }

        let settingsView = SettingsView(store: store, hotkey: hotkey, autoLaunch: autoLaunch, accessibility: accessibility)
        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "偏好设置"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        preferencesWindow = window
    }

    func openAboutWindow() {
        NSApp.activate(ignoringOtherApps: true)

        if let aboutWindow = aboutWindow {
            aboutWindow.makeKeyAndOrderFront(nil)
            return
        }

        let aboutView = AboutView()
        let hostingController = NSHostingController(rootView: aboutView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "关于"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        aboutWindow = window
    }
}

#if !TESTING
@main
struct ClipboardHistoryApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
#endif
