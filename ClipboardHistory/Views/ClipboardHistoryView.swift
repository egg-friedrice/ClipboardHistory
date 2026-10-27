import SwiftUI

/// 菜单栏历史面板主界面。
///
/// 渲染对应：
/// - contract S01（主面板默认状态）/ S02（搜索过滤态）/ S04（空状态）
/// - contract S05（清空全部二次确认）
/// - contract S07（列表项右键删除 / hover）
/// - contract S12（点击写回反馈，方案 A：直接关闭面板）
struct ClipboardHistoryView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var accessibility: AccessibilityService
    @Binding var isPresented: Bool
    var onPreview: (ClipboardItem) -> Void

    /// 用于从右键菜单打开偏好设置 / 关于窗口（contract S06）。
    @Environment(\.openWindow) private var openWindow

    @State private var keyword: String = ""
    @State private var escMonitor: Any?
    @FocusState private var searchFieldFocused: Bool

    /// 是否处于搜索态（keyword 去空格后非空）。
    private var isSearching: Bool {
        !keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 底栏文案（contract S01/S02/S15）。
    /// - 搜索态：「共 X 条匹配」
    /// - 非搜索 + 过期开启：「共 X 条 · 自动过期 Nh」
    /// - 非搜索 + 过期关闭：「共 X 条」
    private var footerText: String {
        let count = displayedItems.count
        if isSearching {
            return "共 \(count) 条匹配"
        }
        let interval = store.expirationInterval
        guard !store.savesHistory, interval > 0 else {
            return "共 \(count) 条"
        }
        let hours = interval / 3600
        return "共 \(count) 条 · 自动过期 \(hours)h"
    }

    /// 当前列表数据源：keyword 为空 → 全量；否则 → 仅匹配文本（图片条目一律隐藏，contract S02）。
    private var displayedItems: [ClipboardItem] {
        isSearching ? store.filtered(by: keyword) : store.items
    }

    var body: some View {
        VStack(spacing: 0) {
            // 暂停监听提示条（contract S03，位置在搜索框上方）。
            // 优先级：S03 提示条 > S14 辅助功能未授权提示条（同时存在时按 S03 在上 S14 在下）。
            if store.isPaused {
                PauseBanner(onResume: {
                    store.isPaused = false
                })
                .padding(.horizontal, 8)
                .padding(.top, 8)
            }

            // 辅助功能未授权提示条（contract S14，在暂停提示条下方、搜索框上方）。
            if !accessibility.isTrusted {
                AccessibilityBanner(onAuthorize: {
                    accessibility.openSystemSettings()
                })
                .padding(.horizontal, 8)
                .padding(.top, store.isPaused ? 4 : 8)
            }

            // 顶部搜索框（contract S01 placeholder = "搜索..."；S02 输入框背景半透明白 0.7）。
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索...", text: $keyword)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($searchFieldFocused)
                    .onSubmit { }
                if !keyword.isEmpty {
                    Button {
                        keyword = ""
                        searchFieldFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(
                Color(nsColor: .textBackgroundColor).opacity(0.7),
                in: RoundedRectangle(cornerRadius: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(.tertiary, lineWidth: 0.5)
            )
            .padding(8)

            // 中间列表 / 空状态 / 搜索无匹配。
            if displayedItems.isEmpty {
                Spacer()
                Text(isSearching ? "未匹配的剪贴板记录" : "暂无剪贴板历史")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))
                Spacer()
            } else {
                List {
                    ForEach(displayedItems) { item in
                        ClipboardRowView(
                            item: item,
                            highlightKeyword: keyword,
                            onTap: { handleTap(item) },
                            onDelete: { store.remove(item.id) },
                            onPreview: { onPreview(item) }
                        )
                        .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            Divider()

            // 底栏：搜索态显示 "共 X 条匹配"（contract S02），否则 "共 X 条"（contract S01/S04）。
            // 自动过期开启时追加 "· 自动过期 Nh"（contract S15）。
            HStack {
                Text(footerText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("清空全部") {
                    confirmClearAll()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .font(.system(size: 11))
                .disabled(displayedItems.isEmpty)
                .opacity(displayedItems.isEmpty ? 0.4 : 1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(minWidth: 320, idealWidth: 360, minHeight: 400, idealHeight: 480)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            DispatchQueue.main.async {
                searchFieldFocused = true
            }
            escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 { handleEscape(); return nil }
                return event
            }
        }
        .onDisappear {
            if let monitor = escMonitor {
                NSEvent.removeMonitor(monitor)
                escMonitor = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openPreferencesFromMenu)) { _ in
            openWindow(id: "preferences")
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAboutFromMenu)) { _ in
            openWindow(id: "about")
        }
        // 注：右键菜单的 onPreferences/onAbout 现在由 App 层直接打开窗口，
        // 不再依赖通知。此处保留作为左键面板内可能的未来扩展入口。
    }

    /// 写回历史记录，关闭面板，再恢复原应用并粘贴。
    private func handleTap(_ item: ClipboardItem) {
        let shouldPaste = store.pendingPasteAfterSelection
        let targetPID = store.pendingPastePID
        // 用完即清，避免下次点击仍触发粘贴。
        store.pendingPasteAfterSelection = false
        store.pendingPastePID = 0

        store.writeBack(item)
        closePanel()

        guard shouldPaste else { return }

        guard targetPID > 0 else { return }
        PasteSimulator.paste(pid: targetPID) { error in
            guard let error else { return }
            NSLog("[ClipboardHistoryView] paste failed: \(error)")
            // 面板已关闭，使用独立提示保证错误可见；内容仍在剪贴板中。
            let alert = NSAlert()
            alert.messageText = "已复制，未能自动粘贴"
            alert.informativeText = "请回到输入框手动按 ⌘V。自动粘贴需要辅助功能权限。"
            alert.addButton(withTitle: "好")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    /// Esc 行为：搜索框有内容 → 清空；搜索框已空 → 关闭面板。
    private func handleEscape() {
        if !keyword.isEmpty {
            keyword = ""
            searchFieldFocused = true
        } else {
            closePanel()
        }
    }

    /// 通过绑定关闭 AppDelegate 持有的弹出面板。
    private func closePanel() {
        isPresented = false
    }

    /// 清空全部二次确认（contract S05）。
    /// 用 NSAlert.runModal 替代 SwiftUI confirmationDialog，
    /// 因为 MenuBarExtra panel 中 confirmationDialog 的 sheet 无法正确获取焦点，
    /// 导致按钮点击不生效。NSAlert 作为独立模态窗口不存在此问题。
    private func confirmClearAll() {
        let alert = NSAlert()
        alert.messageText = "确定清空全部剪贴板历史？"
        alert.informativeText = "此操作不可撤销"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "清空")
        alert.addButton(withTitle: "取消")

        // 确保面板在前台，然后弹出独立 alert 窗口。
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            store.clearAll()
        }
    }
}
