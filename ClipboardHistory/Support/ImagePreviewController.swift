import AppKit
import CryptoKit

/// 生命周期独立于历史面板；同一份图片数据只持有一个窗口。
final class ImagePreviewController: NSObject, NSWindowDelegate {
    private var windows: [SHA256.Digest: NSWindow] = [:]
    private var escapeMonitor: Any?
    private var cascadePoint = NSPoint.zero

    func show(_ item: ClipboardItem) {
        guard item.type == .image, let data = item.imageData else { return }
        let key = SHA256.hash(data: data)
        if let window = windows[key] {
            NSApp.activate(ignoringOtherApps: true)
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
            return
        }

        guard let image = NSImage(data: data), image.isValid else {
            let alert = NSAlert()
            alert.messageText = "无法预览图片"
            alert.informativeText = "图片数据已损坏或格式不受支持。"
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
            return
        }

        // 使用原始像素尺寸，避免 PNG 的 DPI 元数据导致预览被缩小。
        let bitmap = image.representations.compactMap { $0 as? NSBitmapImageRep }.first
        let size = bitmap.map { NSSize(width: $0.pixelsWide, height: $0.pixelsHigh) } ?? image.size
        guard size.width > 0, size.height > 0 else { return }
        image.size = size

        let imageView = NSImageView(frame: NSRect(origin: .zero, size: size))
        imageView.image = image
        imageView.imageScaling = .scaleNone
        imageView.imageAlignment = .alignTopLeft
        imageView.setAccessibilityLabel("原尺寸图片预览")

        let scrollView = NSScrollView()
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = imageView

        let visibleFrame = (NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1024, height: 768))
        let contentSize = NSSize(
            width: min(max(size.width, 240), visibleFrame.width * 0.9),
            height: min(max(size.height, 160), visibleFrame.height * 0.8)
        )
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = "图片预览 · \(Int(size.width))×\(Int(size.height))"
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.tabbingMode = .disallowed
        window.contentView = scrollView
        window.delegate = self
        window.center()
        if cascadePoint == .zero { cascadePoint = NSPoint(x: window.frame.minX, y: window.frame.maxY) }
        cascadePoint = window.cascadeTopLeft(from: cascadePoint)
        windows[key] = window
        installEscapeMonitorIfNeeded()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        // AppKit 的文档坐标原点在左下角，初次打开从图片左上角开始看。
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: max(0, size.height - scrollView.contentSize.height)))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func installEscapeMonitorIfNeeded() {
        guard escapeMonitor == nil else { return }
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.keyCode == 53, NSApp.modalWindow == nil,
                  let window = event.window,
                  self.windows.values.contains(where: { $0 === window }) else { return event }
            self.closeAll()
            return nil
        }
    }

    func closeAll() {
        // close 会同步触发 windowWillClose 并修改字典，先创建快照。
        for window in Array(windows.values) {
            window.close()
        }
    }

    deinit {
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let key = windows.first(where: { $0.value === window })?.key else { return }
        windows.removeValue(forKey: key)
        if windows.isEmpty {
            cascadePoint = .zero
            if let escapeMonitor {
                NSEvent.removeMonitor(escapeMonitor)
                self.escapeMonitor = nil
            }
        }
    }
}
