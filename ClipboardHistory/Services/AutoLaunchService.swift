import Combine
import Foundation
import ServiceManagement

/// 开机自启动服务（SMAppService，macOS 13+）。
///
/// 行为契约对齐：
/// - PRD 3.9「默认开启」+ contract S08「开机自启动 Toggle 默认 on」。
/// - PRD 4.1「SMAppService 注册失败 仅日志记录，不阻塞启动」。
///
/// UI 集成（Step 11 S08）：
/// - `@Published var isEnabled` 作为偏好设置面板「开机自启动」Toggle 的绑定。
/// - `setEnabled(_:)` 由 Toggle 切换调用，失败时 isEnabled 不变、App 不崩溃。
final class AutoLaunchService: ObservableObject {

    /// 反映当前注册状态。Step 11 起作为偏好设置 Toggle 绑定。
    @Published private(set) var isEnabled: Bool = false

    private let service: SMAppService = .mainApp

    init() {
        // 启动时同步一次当前系统注册状态（用户可能在系统设置中改过）。
        isEnabled = (service.status == .enabled)
    }

    /// 注册开机自启动。成功后 isEnabled = true。
    /// 抛错由调用方决定是否兜底；`setEnabled` 已做兜底。
    func enable() throws {
        try service.register()
        isEnabled = (service.status == .enabled)
    }

    /// 注销开机自启动。成功后 isEnabled = false。
    func disable() throws {
        try service.unregister()
        isEnabled = (service.status == .enabled)
    }

    /// 由 Toggle 调用的安全开关：内部 do-catch，失败仅日志记录 + isEnabled 不变。
    /// 行为对齐 PRD 4.1「SMAppService 注册失败 仅日志记录，不阻塞启动」。
    func setEnabled(_ value: Bool) {
        do {
            if value {
                try enable()
            } else {
                try disable()
            }
        } catch {
            NSLog("[AutoLaunchService] setEnabled(\(value)) failed: \(error)")
            // 不更新 isEnabled，与系统实际状态保持一致。
        }
    }

    /// 默认开启策略：仅在系统当前未注册时尝试注册一次。
    /// 失败仅日志记录，不阻塞启动。可在 App 启动时调用。
    func ensureDefaultEnabled() {
        guard service.status != .enabled else {
            isEnabled = true
            return
        }
        do {
            try enable()
        } catch {
            NSLog("[AutoLaunchService] ensureDefaultEnabled failed: \(error)")
            isEnabled = (service.status == .enabled)
        }
    }
}
