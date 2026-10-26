import SwiftUI

/// 全局色彩规范适配（contract 末尾段）。
///
/// 硬编码强调色必须适配暗色模式。以下扩展使用 `NSColor(name:dynamicProvider:)`
/// 根据 appearance 在 Light/Dark 间自动切换。
///
/// | 用途 | Light | Dark |
/// |------|-------|------|
/// | 系统红（destructive） | #d70015 | #ff453a |
/// | 系统绿（success） | #34c759 | #30d158 |
/// | 系统橙（warning） | #ff9500 | #ff9f0a |
/// | 橙色提示条文字 | #c34a00 | #ffa600 |
/// | 次要文字 | #86868b | #98989d |
/// | 信息行值色 | #6e6e73 | #aeaeb2 |
///
/// 系统蓝 #0a84ff 在 Light/Dark 一致，直接用 Color(red:green:blue:)。

/// 判断当前 appearance 是否为暗色模式。
func isDark(_ appearance: NSAppearance) -> Bool {
    appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
}

extension Color {
    /// 系统红：Light #d70015 / Dark #ff453a。
    static let destructiveRed = Color(NSColor(name: nil) { appearance in
        isDark(appearance)
            ? NSColor(red: 0xff/255, green: 0x45/255, blue: 0x3a/255, alpha: 1)
            : NSColor(red: 0xd7/255, green: 0x00/255, blue: 0x15/255, alpha: 1)
    })

    /// 系统绿：Light #34c759 / Dark #30d158。
    static let successGreen = Color(NSColor(name: nil) { appearance in
        isDark(appearance)
            ? NSColor(red: 0x30/255, green: 0xd1/255, blue: 0x58/255, alpha: 1)
            : NSColor(red: 0x34/255, green: 0xc7/255, blue: 0x59/255, alpha: 1)
    })

    /// 系统橙：Light #ff9500 / Dark #ff9f0a。
    static let warningOrange = Color(NSColor(name: nil) { appearance in
        isDark(appearance)
            ? NSColor(red: 0xff/255, green: 0x9f/255, blue: 0x0a/255, alpha: 1)
            : NSColor(red: 0xff/255, green: 0x95/255, blue: 0x00/255, alpha: 1)
    })

    /// 橙色提示条文字：Light #c34a00 / Dark #ffa600。
    static let orangeBannerText = Color(NSColor(name: nil) { appearance in
        isDark(appearance)
            ? NSColor(red: 0xff/255, green: 0xa6/255, blue: 0x00/255, alpha: 1)
            : NSColor(red: 0xc3/255, green: 0x4a/255, blue: 0x00/255, alpha: 1)
    })

    /// 次要文字：Light #86868b / Dark #98989d。
    static let secondaryLabel = Color(NSColor(name: nil) { appearance in
        isDark(appearance)
            ? NSColor(red: 0x98/255, green: 0x98/255, blue: 0x9d/255, alpha: 1)
            : NSColor(red: 0x86/255, green: 0x86/255, blue: 0x8b/255, alpha: 1)
    })

    /// 信息行值色：Light #6e6e73 / Dark #aeaeb2。
    static let infoValue = Color(NSColor(name: nil) { appearance in
        isDark(appearance)
            ? NSColor(red: 0xae/255, green: 0xae/255, blue: 0xb2/255, alpha: 1)
            : NSColor(red: 0x6e/255, green: 0x6e/255, blue: 0x73/255, alpha: 1)
    })

    /// 系统蓝 #0a84ff（Light/Dark 一致）。
    static let systemBlue = Color(red: 0x0a/255, green: 0x84/255, blue: 0xff/255)
}
