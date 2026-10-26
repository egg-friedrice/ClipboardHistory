import Foundation

enum ClipboardType: String, Codable {
    case text
    case image
}

struct ClipboardItem: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let type: ClipboardType
    let text: String?
    let imageData: Data?
    let timestamp: Date

    var displayText: String {
        guard let text else { return "" }
        return String(text.prefix(200))
    }

    static func makeText(_ text: String) -> ClipboardItem {
        ClipboardItem(
            id: UUID(),
            type: .text,
            text: text,
            imageData: nil,
            timestamp: Date()
        )
    }

    static func makeImage(_ data: Data) -> ClipboardItem {
        ClipboardItem(
            id: UUID(),
            type: .image,
            text: nil,
            imageData: data,
            timestamp: Date()
        )
    }
}
