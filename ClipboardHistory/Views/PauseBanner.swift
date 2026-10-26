import SwiftUI

/// 暂停监听提示条（contract S03）。
///
/// 位置：在搜索框上方。
/// 文案：左 "⛔ 监听已暂停"（含 emoji），右 "恢复" 按钮。
/// 视觉关键属性（对齐 contract S03）：
/// - 提示条背景：`Color.orange.opacity(0.12)`
/// - 文字颜色：#c34a00 → `Color(red: 0.77, green: 0.29, blue: 0)`
/// - "恢复"按钮背景：`Color.orange.opacity(0.18)`
/// - "恢复"按钮文字：#c34a00
/// - padding 8，圆角 6
///
/// 优先级（与 S14 辅助功能未授权提示条共存时）：本提示条在更上方。
/// 实现：本 View 只负责渲染；垂直布局顺序由 ClipboardHistoryView 控制。
struct PauseBanner: View {
    /// 点击"恢复"时触发。由父视图传入 store.isPaused = false。
    var onResume: () -> Void

    /// contract S03 文字颜色 #c34a00（暗色 #ffa600）。
    private let textColor = Color.orangeBannerText

    var body: some View {
        HStack(spacing: 8) {
            Text("⛔ 监听已暂停")
                .foregroundStyle(textColor)
                .font(.system(size: 12))
            Spacer()
            Button(action: onResume) {
                Text("恢复")
                    .foregroundStyle(textColor)
                    .font(.system(size: 12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Color.orange.opacity(0.18),
                        in: RoundedRectangle(cornerRadius: 4)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(
            Color.orange.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 6)
        )
    }
}
