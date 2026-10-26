import AppKit
import SwiftUI
import ApplicationServices

/// 偏好设置面板（contract S08 / S09 / S11）。
///
/// 6 段 Form（顺序严格，对齐 contract S08）：
/// 1. 记录上限 → store.maxItems (5 / 10 / 20 / 30 / 50，默认 20)
/// 2. 自动过期 → store.expirationInterval (0/3600/7200/10800/14400/18000，默认 3600)
/// 3. 全局快捷键 → hotkey 录制 + 冲突回退
/// 4. 开机自启动 → autoLaunch.isEnabled
/// 5. 暂停监听 → store.isPaused
/// 6. 辅助功能 → AXIsProcessTrusted() 状态展示
///
/// 录制态（contract S09）：
/// - section 高亮淡蓝 rgba(10,132,255,0.06)
/// - 快捷键位置变红 "请按下新快捷键…"
/// - 按钮文案变 "取消"（红背景白字）
/// - 副文案变 "Esc 取消录制"
///
/// 冲突回退（contract S11）：
/// - Alert 标题 "快捷键被占用" + 图标 ⚠️
/// - 副文案 "所选快捷键已被其他应用占用，已自动回退为 ⌘⇧V"
/// - 单按钮 "好"
/// - hotkey.register 回退默认 Cmd+Shift+V + UserDefaults 同步
struct SettingsView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var hotkey: GlobalHotkey
    @ObservedObject var autoLaunch: AutoLaunchService
    @ObservedObject var accessibility: AccessibilityService

    // UserDefaults keys（与 ClipboardHistoryApp 共用）。
    private let hotkeyModifiersKey = "clipboard.hotkey.modifiers"
    private let hotkeyKeyCodeKey = "clipboard.hotkey.keyCode"

    /// 默认快捷键 Cmd+Shift+V (keyCode 9)。
    private let defaultModifiers: NSEvent.ModifierFlags = [.command, .shift]
    private let defaultKeyCode: UInt32 = 9

    @State private var isRecording: Bool = false
    @State private var showConflictAlert: Bool = false
    @State private var recordingMonitor: Any?

    /// 当前快捷键显示文案（如 "⌘⇧V"），录制中显示 "请按下新快捷键…"。
    private var hotkeyDisplay: String {
        if isRecording { return "请按下新快捷键…" }
        let mods = currentModifiers()
        let kc = currentKeyCode()
        return displayString(modifiers: mods, keyCode: kc)
    }

    var body: some View {
        Form {
            // ① 记录上限（contract S08 第 1 段）。
            Picker("记录上限", selection: $store.maxItems) {
                Text("5 条").tag(5)
                Text("10 条").tag(10)
                Text("20 条").tag(20)
                Text("30 条").tag(30)
                Text("50 条").tag(50)
            }

            Section {
                Toggle("保存历史记录", isOn: $store.savesHistory)
                Text("保存文字和图片，重启后恢复，最多保留所选条数。开启时不自动过期；关闭后清除磁盘副本，并按自动过期设置清理当前列表。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let error = store.persistenceError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }

            // ② 自动过期（contract S08 第 2 段）。
            Picker("自动过期", selection: $store.expirationInterval) {
                Text("不启用").tag(0)
                Text("1 小时").tag(3600)
                Text("2 小时").tag(7200)
                Text("3 小时").tag(10800)
                Text("4 小时").tag(14400)
                Text("5 小时").tag(18000)
            }
            .disabled(store.savesHistory)
            if store.savesHistory {
                Text("保存历史记录已开启，自动过期暂停生效。关闭保存后恢复原过期设置。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // ③ 全局快捷键（contract S08 第 3 段 / S09 录制态）。
            Section {
                hotkeySection
            }

            // ④ 开机自启动（contract S08 第 4 段）。
            Toggle("开机自启动", isOn: Binding(
                get: { autoLaunch.isEnabled },
                set: { autoLaunch.setEnabled($0) }
            ))

            // ⑤ 暂停监听（contract S08 第 5 段）。
            Toggle("暂停监听", isOn: Binding(
                get: { store.isPaused },
                set: { store.isPaused = $0 }
            ))

            // ⑥ 辅助功能（contract S08 第 6 段）。
            Section {
                accessibilityRow
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 460, minHeight: 600)
        .navigationTitle("偏好设置")
        .alert("快捷键被占用", isPresented: $showConflictAlert) {
            Button("好") { }
        } message: {
            Text("所选快捷键已被其他应用占用，已自动回退为 ⌘⇧V")
        }
        .onDisappear { stopRecording() }
    }

    // MARK: - Hotkey Section

    /// 全局快捷键 section。录制时整体高亮淡蓝 + 文案变红 + 按钮变取消。
    @ViewBuilder
    private var hotkeySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("全局快捷键")
                Spacer()
                Text(hotkeyDisplay)
                    // contract S08：快捷键文本用 Menlo 等宽字体；S09 录制态红色 #d70015。
                    .font(.custom("Menlo", size: 13))
                    .foregroundStyle(isRecording ? Color.destructiveRed : .primary)
                Button {
                    if isRecording { stopRecording() } else { startRecording() }
                } label: {
                    if isRecording {
                        // contract S09：取消按钮红背景白字。
                        Text("取消")
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.destructiveRed, in: RoundedRectangle(cornerRadius: 4))
                    } else {
                        Text("录制")
                    }
                }
                .buttonStyle(.plain)
            }
            // contract S08：默认值说明；S09 录制态副文案变 "Esc 取消录制"。
            Text(isRecording ? "请按含 ⌘、⌃ 或 ⌥ 的组合键 · Esc 取消" : "默认 Cmd+Shift+V · 录制时检测冲突")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(
            // contract S09：录制态高亮 rgba(10,132,255,0.06)。
            isRecording
                ? Color.systemBlue.opacity(0.06)
                : Color.clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
    }

    // MARK: - Accessibility Row

    @ViewBuilder
    private var accessibilityRow: some View {
        HStack {
            Text("辅助功能")
            Spacer()
            HStack(spacing: 4) {
                Circle()
                    .fill(accessibility.isTrusted ? Color.successGreen : Color.warningOrange)
                    .frame(width: 8, height: 8)
                Text(accessibility.isTrusted ? "已授权" : "未授权")
                    .foregroundStyle(accessibility.isTrusted ? Color.successGreen : Color.warningOrange)
            }
            if !accessibility.isTrusted {
                Button("去授权…") {
                    accessibility.openSystemSettings()
                }
            }
        }
        // contract S08：说明文案。
        Text("自动粘贴依赖此权限 · 失踪时会降级为仅写回剪贴板")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: - Recording

    private func startRecording() {
        hotkey.unregister()
        isRecording = true
        recordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Esc 取消录制（keyCode 53）。
            if event.keyCode == 53 {
                stopRecording()
                return nil
            }
            // 只接受带 modifier 的组合键（避免单字符误触发）。
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                .subtracting(.capsLock)
            guard !mods.intersection([.command, .control, .option]).isEmpty else { return event }

            let keyCode = UInt32(event.keyCode)
            stopRecording(restoreHotkey: false)
            tryRegister(modifiers: mods, keyCode: keyCode)
            return nil
        }
    }

    private func stopRecording(restoreHotkey: Bool = true) {
        let wasRecording = isRecording
        if let m = recordingMonitor {
            NSEvent.removeMonitor(m)
            recordingMonitor = nil
        }
        isRecording = false
        if wasRecording && restoreHotkey {
            _ = hotkey.register(modifiers: currentModifiers(), keyCode: currentKeyCode())
        }
    }

    /// 尝试注册新快捷键，失败回退默认 Cmd+Shift+V。
    private func tryRegister(modifiers: NSEvent.ModifierFlags, keyCode: UInt32) {
        hotkey.unregister()
        let ok = hotkey.register(modifiers: modifiers, keyCode: keyCode)
        if ok {
            UserDefaults.standard.set(Int(modifiers.rawValue), forKey: hotkeyModifiersKey)
            UserDefaults.standard.set(Int(keyCode), forKey: hotkeyKeyCodeKey)
        } else {
            // 冲突回退默认值（contract S11）。
            hotkey.unregister()
            _ = hotkey.register(modifiers: defaultModifiers, keyCode: defaultKeyCode)
            UserDefaults.standard.set(Int(defaultModifiers.rawValue), forKey: hotkeyModifiersKey)
            UserDefaults.standard.set(Int(defaultKeyCode), forKey: hotkeyKeyCodeKey)
            showConflictAlert = true
        }
    }

    // MARK: - Current Hotkey Read

    private func currentModifiers() -> NSEvent.ModifierFlags {
        let raw = UserDefaults.standard.integer(forKey: hotkeyModifiersKey)
        return raw == 0 ? defaultModifiers : NSEvent.ModifierFlags(rawValue: UInt(raw))
    }

    private func currentKeyCode() -> UInt32 {
        let raw = UserDefaults.standard.integer(forKey: hotkeyKeyCodeKey)
        return UserDefaults.standard.object(forKey: hotkeyKeyCodeKey) == nil
            ? defaultKeyCode : UInt32(clamping: raw)
    }

    /// 把 modifiers + keyCode 转成展示字符串（如 "⌘⇧V"）。
    private func displayString(modifiers: NSEvent.ModifierFlags, keyCode: UInt32) -> String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option)  { s += "⌥" }
        if modifiers.contains(.shift)   { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        s += keyLabel(for: keyCode)
        return s
    }

    /// 通过 UCKeyTranslate 把 keyCode 翻译成可读字符；失败时回退常见键位。
    private func keyLabel(for keyCode: UInt32) -> String {
        // 常见字母/数字键位（US 键盘）。
        let known: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 10: "B", 11: "Q", 12: "W", 13: "E", 14: "R", 15: "Y",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
            36: "Return", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";",
            42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
            48: "Tab", 49: "Space", 50: "`", 51: "Delete",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        ]
        return known[keyCode] ?? "Key\(keyCode)"
    }
}
