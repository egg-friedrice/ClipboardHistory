import SwiftUI

/// 辅助功能未授权提示条（contract S14）。
///
/// 位置：在暂停提示条下方、搜索框上方（同时存在时 S03 在上、S14 在下）。
/// 文案：左 "⚠️ 辅助功能未授权，无法自动粘贴"，右 "去授权"。
/// 视觉关键属性（对齐 contract S14）：
/// - 提示条背景：`rgba(255,149,0,0.12)` → `Color(red:1, 149/255, 0).opacity(0.12)`
/// - 文字颜色 / 按钮文字颜色：#c34a00 → `Color(red:0.77, 0.29, 0)`
/// - 按钮背景：`rgba(255,149,0,0.18)`
///
/// 点击"去授权" → 父视图调 `AccessibilityService.openSystemSettings()`：
/// 打开 `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`。
struct AccessibilityBanner: View {
    var onAuthorize: () -> Void

    /// contract S14 文字颜色 #c34a00（暗色 #ffa600）。
    private let textColor = Color.orangeBannerText

    var body: some View {
        HStack(spacing: 8) {
            Text("⚠️ 辅助功能未授权，无法自动粘贴")
                .foregroundStyle(textColor)
                .font(.system(size: 12))
                .lineLimit(1)
            Spacer()
            Button(action: onAuthorize) {
                Text("去授权")
                    .foregroundStyle(textColor)
                    .font(.system(size: 12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Color.warningOrange.opacity(0.18),
                        in: RoundedRectangle(cornerRadius: 4)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(
            Color.warningOrange.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 6)
        )
    }
}
