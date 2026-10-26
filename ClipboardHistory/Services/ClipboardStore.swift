import AppKit
import Combine
import Foundation

/// 内存和磁盘共用同一份有序历史，文字与图片统一保存。
/// 磁盘使用 Application Support 下的二进制 plist，原子替换避免半写文件。
final class ClipboardStore: ObservableObject {
    private var isRestoring = true

    /// 内存全量（含图片）。按 timestamp 倒序排列（最新在前）。
    @Published private(set) var items: [ClipboardItem] = []

    /// 上限，默认 20。set 时自动裁剪到上限（丢弃最旧的）。
    @Published var maxItems: Int = 20 {
        didSet {
            guard !isRestoring else { return }
            guard maxItems != oldValue else { return }
            trimToMax()
            persistHistory()
            defaults.set(maxItems, forKey: ClipboardStore.maxItemsKey)
        }
    }

    /// 关闭保存会删除磁盘副本，但保留本次运行的内存历史。
    @Published var savesHistory: Bool = false {
        didSet {
            guard !isRestoring else { return }
            guard savesHistory != oldValue else { return }
            defaults.set(savesHistory, forKey: Self.savesHistoryKey)
            if !savesHistory && expirationInterval > 0 {
                let cutoff = Date().addingTimeInterval(-TimeInterval(expirationInterval))
                items.removeAll { $0.timestamp < cutoff }
            }
            persistHistory()
        }
    }
    @Published private(set) var persistenceError: String?
    private let defaults: UserDefaults
    private let historyURL: URL
    private static let savesHistoryKey = "clipboard.savesHistory"

    /// 自动过期时长（秒），0 = 不启用。默认 3600（1 小时）。
    /// didSet 时持久化到 UserDefaults，并触发 scanner 立即扫描（contract S15）。
    @Published var expirationInterval: Int = 3600 {
        didSet {
            guard !isRestoring else { return }
            guard expirationInterval != oldValue else { return }
            defaults.set(expirationInterval, forKey: ClipboardStore.expirationKey)
            // 时长变更立即生效，按新时长裁剪。
            scanner?.scanOnce()
        }
    }

    /// UserDefaults 持久化 key。
    private static let storageKey = "clipboard.text.history"
    private static let maxItemsKey = "clipboard.maxItems"
    private static let expirationKey = "clipboard.expirationInterval"

    /// 内部持有的监听器。启动后自动监听并 append 新条目。
    private let monitor: ClipboardMonitor

    /// 过期扫描器引用（weak 由 scanner 持有 store，这里持有 scanner）。
    /// 由 App 层在启动时注入；expirationInterval didSet 调用 scanner.scanOnce()。
    var scanner: ExpirationScanner?

    /// 通过 monitor 透出的暂停状态。
    var isPaused: Bool {
        get { monitor.isPaused }
        set { monitor.setPaused(newValue) }
    }

    /// 待粘贴标志：打开列表时存在外部目标应用且已授权时置 true，
    /// ClipboardHistoryView handleTap 选中条目后读取并执行延迟 paste，用完置 false。
    /// 这是 Step 12 自动粘贴链路唯一跨模块的状态，挂在 store 上让 View 可观察。
    @Published var pendingPasteAfterSelection: Bool = false
    /// pendingPaste 时记录目标 pid（PasteSimulator.postToPid 用）。0 表示交给前台 App。
    @Published var pendingPastePID: pid_t = 0

    init(maxItems: Int = 20, defaults: UserDefaults = .standard,
         historyURL: URL? = nil, startMonitoring: Bool = true) {
        self.defaults = defaults
        self.historyURL = historyURL ?? FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0].appendingPathComponent("com.clipboard.ClipboardHistory", isDirectory: true)
            .appendingPathComponent("history.plist")
        self.monitor = ClipboardMonitor()
        let savedMax = defaults.object(forKey: Self.maxItemsKey) as? Int
        self.maxItems = [5, 10, 20, 30, 50].contains(savedMax ?? maxItems) ? (savedMax ?? maxItems) : 20
        self.expirationInterval = defaults.object(forKey: Self.expirationKey) as? Int ?? 3600
        self.savesHistory = defaults.object(forKey: Self.savesHistoryKey) as? Bool ?? false

        isRestoring = false
        if savesHistory {
            loadHistory()
        } else {
            persistHistory()
        }
        monitor.onNewItem = { [weak self] item in self?.append(item) }
        if startMonitoring { monitor.start() }
    }

    deinit {
        monitor.stop()
    }

    // MARK: - Public Mutation

    /// 追加新条目到列表头部，并自动裁剪到 maxItems。
    func append(_ item: ClipboardItem) {
        items.insert(item, at: 0)
        trimToMax()
        persistHistory()
    }

    /// 按 IndexSet 删除（用于 SwiftUI List 的 delete）。
    func remove(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        persistHistory()
    }

    /// 按 id 删除。
    func remove(_ id: UUID) {
        if let idx = items.firstIndex(where: { $0.id == id }) {
            items.remove(at: idx)
            persistHistory()
        }
    }

    /// 清空全部。
    func clearAll() {
        items.removeAll()
        persistHistory()
    }

    /// 关键字过滤：文本包含（忽略大小写）；图片不参与搜索。
    func filtered(by keyword: String) -> [ClipboardItem] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        return items.filter { item in
            guard item.type == .text, let text = item.text else { return false }
            return text.localizedCaseInsensitiveContains(trimmed)
        }
    }

    /// 写回剪贴板：在写回前后设置 monitor.isWritingBack，避免循环记录。
    /// 写回失败时静默失败（PRD 4.1：日志记录，不崩溃）。
    func writeBack(_ item: ClipboardItem) {
        monitor.isWritingBack = true
        defer { monitor.finishWriteBack() }

        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.type {
        case .text:
            let ok = pb.setString(item.text ?? "", forType: .string)
            if !ok {
                NSLog("[ClipboardStore] writeBack: pb.setString failed for text item")
            }
        case .image:
            if let data = item.imageData, let image = NSImage(data: data) {
                let ok = pb.writeObjects([image])
                if !ok {
                    NSLog("[ClipboardStore] writeBack: pb.writeObjects failed for image item")
                }
            } else {
                NSLog("[ClipboardStore] writeBack: image data nil or NSImage decode failed")
            }
        }
    }

    // MARK: - Private

    /// 删除 timestamp 早于 cutoff 的条目，并同步持久化（contract S15）。
    /// 供 ExpirationScanner 在主线程 async 块内调用。
    func removeExpiredItems(before cutoff: Date) {
        guard !savesHistory, expirationInterval > 0 else { return }
        items.removeAll { $0.timestamp < cutoff }
        persistHistory()
    }

    /// 裁剪到 maxItems，丢弃最旧的（数组尾部）。
    private func trimToMax() {
        guard maxItems > 0, items.count > maxItems else { return }
        let removeCount = items.count - maxItems
        items.removeLast(removeCount)
    }

    /// 每次修改后原子替换磁盘快照，确保条数、删除和图片与内存一致。
    private func persistHistory() {
        do {
            if savesHistory {
                let encoder = PropertyListEncoder()
                encoder.outputFormat = .binary
                let data = try encoder.encode(items)
                try FileManager.default.createDirectory(at: historyURL.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true)
                try data.write(to: historyURL, options: .atomic)
            } else if FileManager.default.fileExists(atPath: historyURL.path) {
                try FileManager.default.removeItem(at: historyURL)
            }
            // 新格式保存成功或明确关闭保存后，清理旧版文本副本。
            defaults.removeObject(forKey: Self.storageKey)
            persistenceError = nil
        } catch {
            persistenceError = "历史记录保存失败：\(error.localizedDescription)"
            NSLog("[ClipboardStore] persistence failed: \(error)")
        }
    }

    private func loadHistory() {
        do {
            if FileManager.default.fileExists(atPath: historyURL.path) {
                items = try PropertyListDecoder().decode([ClipboardItem].self,
                    from: Data(contentsOf: historyURL))
            } else if let data = defaults.data(forKey: Self.storageKey) {
                items = try JSONDecoder().decode([ClipboardItem].self, from: data)
            }
            items.sort { $0.timestamp > $1.timestamp }
            trimToMax()
            // 保存开启时恢复全部未超出条数上限的记录，不按时间过期。
            persistHistory()
        } catch {
            items = []
            persistenceError = "历史记录读取失败：\(error.localizedDescription)"
            NSLog("[ClipboardStore] load failed: \(error)")
        }
    }
}
