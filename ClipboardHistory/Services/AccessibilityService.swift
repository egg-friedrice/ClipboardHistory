import AppKit
import ApplicationServices
import Combine
import Foundation

/// 辅助功能授权服务。
///
/// 行为契约对齐 contract S14：
/// - 历史面板顶部橙色提示条「⚠️ 辅助功能未授权，无法自动粘贴」+「去授权」按钮。
/// - 授权后 DistributedNotificationCenter 收到通知 → isTrusted=true → 提示条消失。
///
/// PRD 4.1：辅助功能未授权时快捷键降级为「仅写回剪贴板」模式（无自动粘贴）。
final class AccessibilityService: ObservableObject {

    /// 当前是否已授权。
    @Published private(set) var isTrusted: Bool = false

    /// UserDefaults key：是否已弹过一次性系统请求框。
    private let promptedKey = "clipboard.accessibility.prompted"

    init() {
        isTrusted = AXIsProcessTrusted()
        // 监听系统辅助功能授权变化（用户在系统设置中切换时触发）。
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(accessibilityChanged),
            name: NSNotification.Name("com.apple.accessibility.api"),
            object: nil
        )
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    /// 首次启动引导：仅在 prompt 未弹过时调用 AXIsProcessTrustedWithOptions 弹一次性系统请求框。
    /// 后续启动不再主动弹请求框，靠 SettingsView 的「去授权」按钮引导。
    func requestIfNeeded() {
        let alreadyPrompted = UserDefaults.standard.bool(forKey: promptedKey)
        guard !alreadyPrompted else { return }
        UserDefaults.standard.set(true, forKey: promptedKey)
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        isTrusted = AXIsProcessTrustedWithOptions(options)
    }

    /// 手动触发系统请求框（可重复调用，由设置面板/提示条按钮触发）。
    func request() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        isTrusted = AXIsProcessTrustedWithOptions(options)
    }

    /// 打开系统设置 → 隐私与安全性 → 辅助功能。
    func openSystemSettings() {
        if !AXIsProcessTrusted() { request() }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func refresh() {
        isTrusted = AXIsProcessTrusted()
    }

    @objc private func accessibilityChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.isTrusted = AXIsProcessTrusted()
        }
    }
}
