import AppKit
import ApplicationServices
import Foundation

/// 焦点检测：判断当前前台 App 的焦点元素是否是可编辑输入框。
///
/// 用途：GlobalHotkey onTrigger 时分流 —— 输入框聚焦 → 弹面板 + 选条目后自动粘贴；
/// 非输入框 → 仅 toggle 面板（contract S13）。
///
/// 实现：
/// 1. 取 NSWorkspace.shared.frontmostApplication。
/// 2. AXUIElementCreateApplication(pid)。
/// 3. AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute) → 焦点元素。
/// 4. 取焦点元素的 kAXRoleAttribute，判断是否 ∈ {AXTextField, AXTextArea, AXComboBox}。
/// 5. 对于 AXWebArea（Safari/Chrome 网页），进一步取其 focused child 判断是否输入框。
/// 6. 对于 AXGroup 等通用角色，尝试 AXUIElementIsAttributeSettable(kAXValueAttribute) 兜底。
enum InputFocusDetector {

    /// 直接是输入框的角色。
    private static let directInputRoles: Set<String> = [
        "AXTextField",
        "AXTextArea",
        "AXComboBox",
    ]

    /// 当前前台 App 是否聚焦在可编辑输入框。
    /// 返回 (是否输入框, 前台 App pid)。pid 供 PasteSimulator.postToPid 使用。
    static func currentFocusedInput() -> (isInput: Bool, pid: pid_t?) {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return (false, nil)
        }
        let pid = frontApp.processIdentifier
        let app = AXUIElementCreateApplication(pid)

        var focusedRef: CFTypeRef?
        let focusedStatus = AXUIElementCopyAttributeValue(
            app,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        )
        guard focusedStatus == .success, let focused = focusedRef else {
            return (false, pid)
        }
        let focusedElement = focused as! AXUIElement

        return (isEditable(focusedElement), pid)
    }

    /// 判断一个 AXUIElement 是否是可编辑输入框。
    private static func isEditable(_ element: AXUIElement) -> Bool {
        let role = attributeString(element, kAXRoleAttribute)

        // 直接匹配输入框角色。
        if directInputRoles.contains(role) {
            return isValueSettable(element)
        }

        // AXWebArea（网页内容区）：取其 focused child 再判断。
        if role == "AXWebArea" {
            return isWebAreaFocusedEditable(element)
        }

        // 通用兜底：尝试看 Value 是否可设（某些 Electron App / 自定义控件角色可能不标准）。
        if isValueSettable(element) {
            // 进一步确认有 placeholder 或 editable 子属性，减少误判。
            let placeholder = attributeString(element, kAXPlaceholderValueAttribute)
            if !placeholder.isEmpty { return true }
            // 如果角色看起来像 group/button 等就不要误判。
            if role.contains("Group") || role.contains("Button") || role.contains("Menu") {
                return false
            }
            return true
        }

        return false
    }

    /// AXWebArea 焦点下的可编辑元素探测：
    /// 取 kAXFocusedUIElementAttribute 子元素，递归判断是否输入框。
    private static func isWebAreaFocusedEditable(_ webArea: AXUIElement) -> Bool {
        var focusedRef: CFTypeRef?
        AXUIElementCopyAttributeValue(
            webArea,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        )
        guard let focused = focusedRef else { return false }
        let element = focused as! AXUIElement

        // 递归：可能是 AXWebArea → AXGroup → AXTextField 的多层结构。
        return isEditable(element)
    }

    /// 取 AXUIElement 的字符串属性。
    private static func attributeString(_ element: AXUIElement, _ attr: String) -> String {
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(element, attr as CFString, &ref)
        return ref as? String ?? ""
    }

    /// 检查 Value 属性是否可设（是可编辑输入框的强信号）。
    private static func isValueSettable(_ element: AXUIElement) -> Bool {
        var settable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable)
        return settable.boolValue
    }
}
