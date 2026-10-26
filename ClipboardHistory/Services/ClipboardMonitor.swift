import AppKit
import Combine
import Foundation

/// 剪贴板轮询监听器。
///
/// 通过周期性比较 `NSPasteboard.general.changeCount` 来检测剪贴板变化，
/// 把每次变化封装为 `ClipboardItem` 并通过 `onNewItem` 在主线程回调。
///
/// 行为契约对齐：
/// - S03 暂停态：`isPaused == true` 时，轮询跳过 changeCount 比对，新内容不入历史。
/// - S12 写回防循环：外部写回剪贴板前置 `isWritingBack = true`，
///   轮询读到本次 changeCount 变化后跳过处理并复位标志位。
final class ClipboardMonitor: ObservableObject {

    /// 检测到新条目时回调，主线程触发。
    var onNewItem: ((ClipboardItem) -> Void)?

    /// 是否暂停监听（外部只读）。暂停时只跳过比对，Timer 仍在运行。
    @Published private(set) var isPaused: Bool = false

    /// 外部写回剪贴板标志位。写回前置 true，轮询本次变化会被跳过并复位为 false。
    var isWritingBack: Bool = false

    /// 轮询间隔（秒）。PRD 7 决策表：0.3s。
    private let pollInterval: TimeInterval = 0.3

    private var timer: Timer?
    private var lastChangeCount: Int

    /// 内部缓存上次产出的条目，用于去重（type + text/imageData 都相同则跳过）。
    private var lastItem: ClipboardItem?

    init() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    // MARK: - Public

    /// 启动 Timer 轮询。重复调用安全。
    func start() {
        if timer != nil { return }
        // 启动时同步一次当前 changeCount，避免把启动前的最后一条当作新条目。
        lastChangeCount = NSPasteboard.general.changeCount
        let t = Timer.scheduledTimer(
            withTimeInterval: pollInterval,
            repeats: true
        ) { [weak self] _ in
            self?.tick()
        }
        // 保证 Timer 在 RunLoop.common 模式下也触发（避免 UI 交互时漏检）。
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// 停止 Timer 轮询。
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// 暂停 / 恢复监听。暂停时跳过 changeCount 比对，但 Timer 仍运行。
    func setPaused(_ paused: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.isPaused != paused else { return }
            self.isPaused = paused
            // 恢复时把 lastChangeCount 对齐到当前，避免暂停期间复制被恢复后误判为新条目。
            if !paused {
                self.lastChangeCount = NSPasteboard.general.changeCount
            }
        }
    }

    /// 同步写回后的版本，防止下一轮把选中的历史再记录一次。
    func finishWriteBack() {
        lastChangeCount = NSPasteboard.general.changeCount
        isWritingBack = false
    }

    // MARK: - Private

    private func tick() {
        guard !isPaused else { return }

        let pb = NSPasteboard.general
        let current = pb.changeCount

        // 写回防循环：外部写回后会触发 changeCount 变化，本次跳过并复位标志位。
        if isWritingBack {
            lastChangeCount = current
            isWritingBack = false
            return
        }

        guard current != lastChangeCount else { return }
        lastChangeCount = current

        guard let item = readItem(from: pb) else { return }

        // 去重：type + 内容都相同则跳过。
        if isSameAsLast(item) {
            return
        }
        lastItem = item

        DispatchQueue.main.async { [weak self] in
            self?.onNewItem?(item)
        }
    }

    /// 从 pasteboard 读取一个 ClipboardItem。
    /// 优先 string；string 为 nil 且 pasteboard 含 TIFF 类型时读 image。
    private func readItem(from pb: NSPasteboard) -> ClipboardItem? {
        if let str = pb.string(forType: .string), !str.isEmpty {
            return ClipboardItem.makeText(str)
        }

        if let tiffData = pb.data(forType: .tiff), !tiffData.isEmpty {
            if let nsImage = NSImage(data: tiffData),
               let pngData = pngData(from: nsImage) {
                return ClipboardItem.makeImage(pngData)
            }
        }
        return nil
    }

    /// NSImage → PNG Data（用 NSBitmapImageRep 转 pngData）。
    private func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return rep.representation(using: .png, properties: [:])
    }

    /// 与上次产出条目比较：type + text + imageData 都相同返回 true。
    private func isSameAsLast(_ item: ClipboardItem) -> Bool {
        guard let last = lastItem else { return false }
        if last.type != item.type { return false }
        switch item.type {
        case .text:
            return last.text == item.text
        case .image:
            return last.imageData == item.imageData
        }
    }
}
