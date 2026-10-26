import SwiftUI

/// 关于窗口（contract S10）。
///
/// 窗口宽度 280，显示：
/// - 60×60 渐变图标 #5ac8fa → #0a84ff 圆角 12，内含 📋 emoji 30px 白色
/// - App 名 "ClipboardHistory" 15px 加粗
/// - 版本号 "版本 X.Y.Z (B)" 11px，从 Bundle.main 读取
/// - 信息行：Swift 版本 / 最低系统 / Bundle ID，11px，Key 标签宽 75px 颜色 #86868b
/// - 底部说明 "自用剪贴板历史管理工具 · 纯离线 · 菜单栏应用"
struct AboutView: View {

    /// 从 Bundle.main 读取版本号。
    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "版本 \(short) (\(build))"
    }

    /// Bundle ID。
    private var bundleID: String {
        Bundle.main.bundleIdentifier ?? "com.clipboard.ClipboardHistory"
    }

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
            .frame(width: 60, height: 60)
            .padding(.bottom, 12)

            // App 名 15px 加粗。
            Text("ClipboardHistory")
                .font(.system(size: 15, weight: .semibold))
                .padding(.bottom, 4)

            // 版本号 11px 颜色 #86868b（暗色 #98989d）。
            Text(versionString)
                .font(.system(size: 11))
                .foregroundStyle(Color.secondaryLabel)
                .padding(.bottom, 14)

            // 信息区分隔线。
            Divider()
                .opacity(0.5)
                .padding(.bottom, 12)

            // 信息行：每行 Key 标签宽 75px 颜色 #86868b，值颜色 #6e6e73。
            VStack(alignment: .leading, spacing: 0) {
                infoRow(key: "Swift 版本", value: "5.9")
                infoRow(key: "最低系统", value: "macOS 14.0")
                infoRow(key: "Bundle ID", value: bundleID)

                // 底部说明。
                Text("自用剪贴板历史管理工具 · 纯离线 · 菜单栏应用")
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)
                    .padding(.top, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 24)
        .frame(width: 280)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    /// 信息行：Key 标签宽 75px 颜色 #86868b + 值颜色 #6e6e73。
    private func infoRow(key: String, value: String) -> some View {
        HStack(spacing: 0) {
            Text(key)
                .font(.system(size: 11))
                .foregroundStyle(Color.secondaryLabel)
                .frame(width: 75, alignment: .leading)
            Text(value)
                .font(.system(size: 11))
                .foregroundStyle(Color.infoValue)
            Spacer()
        }
        .padding(.vertical, 1)
    }
}
