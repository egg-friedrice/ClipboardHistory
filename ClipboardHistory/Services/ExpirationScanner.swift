import Foundation

/// 自动过期扫描器（contract S15）。
///
/// 每 60 秒扫描一次 `ClipboardStore.items`，删除超过 `expirationInterval` 秒的条目。
/// 启动时立即扫描一次，避免 60s 内残留过期条目。
/// `expirationInterval` 变更时由 `ClipboardStore.didSet` 调用 `scanOnce()` 立即生效。
///
/// 竞态安全：所有 items 读写都在 `DispatchQueue.main.async` 块内串行执行，
/// 与 append / remove 等操作共享同一主线程队列，不会冲突。
final class ExpirationScanner: ObservableObject {

    /// weak 引用 store，避免循环引用。
    weak var store: ClipboardStore?

    /// 定时器，60s 间隔。
    private var timer: Timer?

    /// 启动定时扫描。重复调用安全（先停旧的再加新的）。
    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.scan()
        }
    }

    /// 停止定时扫描。
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// 立即执行一次扫描（不影响定时器周期）。
    /// 可在启动时 / expirationInterval 变更时调用。
    func scanOnce() {
        scan()
    }

    /// 扫描并删除过期条目。
    ///
    /// 1. guard store 存在且 expirationInterval > 0（0 = 不启用）。
    /// 2. 计算 cutoff 时间点。
    /// 3. 在主线程异步块内读 + 写 items，同步磁盘历史。
    ///    所有 items 修改都通过主线程串行化，避免与 append / remove 竞态。
    private func scan() {
        DispatchQueue.main.async { [weak self] in
            guard let store = self?.store,
                  !store.savesHistory, store.expirationInterval > 0 else { return }
            let cutoff = Date().addingTimeInterval(-TimeInterval(store.expirationInterval))
            store.removeExpiredItems(before: cutoff)
        }
    }
}
