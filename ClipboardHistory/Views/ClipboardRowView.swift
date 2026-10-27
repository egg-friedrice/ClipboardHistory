import AppKit
import SwiftUI

/// 历史列表中的一行。
///
/// - 文本条目：左侧 `item.displayText`（已截断 200 字符）。
/// - 图片条目：左侧 `[图片]  <尺寸>×<尺寸>` 文案（contract S01 图片条目文案前缀 `[图片]` 必须出现）。
///   图片缩略图按 contract S01 视觉规范，32×32 缩略图展示。
/// - 右侧：相对时间（`刚刚` / `X 分钟前` / `X 小时前` / `X 天前`），字号 11px（.caption）颜色 `.secondary`。
///
/// 搜索态高亮（contract S02）：传入非空 keyword 时，文本条目中所有大小写不敏感匹配段
/// 用 `.red` (#d70015) 渲染，其余段保持主文本色。
///
/// 交互（contract S07）：
/// - `onTap`：点击整行触发，由父视图实现写回 + 关闭面板。
/// - `onDelete`：右键菜单 .destructive "删除"。
/// - hover 时行背景 `#0a84ff`、文字 white、时间色 rgba(255,255,255,0.85)（contract S07 视觉规范）。
struct ClipboardRowView: View {
    let item: ClipboardItem
    var highlightKeyword: String = ""
    var onTap: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onPreview: (() -> Void)? = nil

    @State private var isHovered: Bool = false

    /// contract S07：hover 背景 #0a84ff（Light/Dark 一致）。
    private let hoverBg = Color.systemBlue
    /// contract S07：hover 时间色 rgba(255,255,255,0.85)。
    private let hoverTimeColor = Color.white.opacity(0.85)

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                leadingView
                VStack(alignment: .leading, spacing: 2) {
                    primaryText
                }
                Spacer(minLength: 4)
                Text(relativeTimeString(from: item.timestamp))
                    .foregroundStyle(isHovered ? hoverTimeColor : Color.secondary)
                    .font(.caption) // ~11px
            }
            .contentShape(Rectangle())
            .onTapGesture { onTap?() }

            if item.type == .image {
                Button("预览") { onPreview?() }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundStyle(isHovered ? Color.white : Color.accentColor)
                    .fixedSize()
                    .help("按原尺寸预览图片")
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isHovered ? hoverBg : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("删除", role: .destructive) {
                onDelete?()
            }
        }
    }

    @ViewBuilder
    private var leadingView: some View {
        switch item.type {
        case .text:
            Image(systemName: "doc.text")
                .foregroundStyle(isHovered ? Color.white : Color.secondary)
                .frame(width: 20)
        case .image:
            if let data = item.imageData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(isHovered ? Color.white : Color.secondary)
                    .frame(width: 32, height: 32)
            }
        }
    }

    @ViewBuilder
    private var primaryText: some View {
        switch item.type {
        case .text:
            highlightedText
        case .image:
            Text(imageLabelText)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(isHovered ? Color.white : Color.primary)
        }
    }

    /// 文本条目主文案。当 highlightKeyword 非空时，把 displayText 中
    /// localizedCaseInsensitiveContains 匹配的子段用 `.red` 染色（contract S02 高亮色 #d70015）。
    /// hover 时整行反白，高亮段保持 .red（与 contract S07 hover 时文字 white 不冲突，匹配段仍红）。
    @ViewBuilder
    private var highlightedText: some View {
        let text = item.displayText
        let trimmed = highlightKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            Text(text)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(isHovered ? Color.white : Color.primary)
        } else if let ranges = caseInsensitiveRanges(of: trimmed, in: text), !ranges.isEmpty {
            Text(attributedSegments(from: text, ranges: ranges, hovered: isHovered))
                .lineLimit(1)
                .truncationMode(.tail)
        } else {
            Text(text)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(isHovered ? Color.white : Color.primary)
        }
    }

    /// 把 text 按 sorted ranges 切分，匹配段用 .red，其余段用 hover ? white : primary。
    private func attributedSegments(from text: String, ranges: [Range<String.Index>], hovered: Bool) -> AttributedString {
        var result = AttributedString()
        var cursor = text.startIndex
        let baseColor: Color = hovered ? .white : .primary
        for r in ranges {
            if cursor < r.lowerBound {
                var seg = AttributedString(String(text[cursor..<r.lowerBound]))
                seg.foregroundColor = baseColor
                result.append(seg)
            }
            var match = AttributedString(String(text[r]))
            match.foregroundColor = Color.destructiveRed
            result.append(match)
            cursor = r.upperBound
        }
        if cursor < text.endIndex {
            var tail = AttributedString(String(text[cursor..<text.endIndex]))
            tail.foregroundColor = baseColor
            result.append(tail)
        }
        return result
    }

    /// 返回 text 中所有大小写不敏感匹配 keyword 的 ranges（按位置升序，无重叠）。
    private func caseInsensitiveRanges(of keyword: String, in text: String) -> [Range<String.Index>]? {
        guard !keyword.isEmpty else { return nil }
        let lowerText = text.lowercased()
        let lowerKeyword = keyword.lowercased()
        var ranges: [Range<String.Index>] = []
        var searchStart = lowerText.startIndex
        while searchStart < lowerText.endIndex,
              let r = lowerText.range(of: lowerKeyword, range: searchStart..<lowerText.endIndex) {
            ranges.append(r)
            searchStart = r.upperBound
            if searchStart == r.lowerBound { break }
        }
        return ranges
    }

    private var imageLabelText: String {
        if let data = item.imageData, let nsImage = NSImage(data: data) {
            let size = nsImage.size
            let w = Int(size.width.rounded())
            let h = Int(size.height.rounded())
            return "[图片]  截图.png · \(w)×\(h)"
        }
        return "[图片]"
    }

    private func relativeTimeString(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "刚刚" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) 分钟前" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) 小时前" }
        let days = hours / 24
        return "\(days) 天前"
    }
}
