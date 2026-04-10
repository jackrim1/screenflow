import Foundation

public struct Screenshot: Identifiable, Hashable {
    public let id: UUID
    public let url: URL
    public let createdAt: Date
    public let filename: String

    public init(url: URL, createdAt: Date) {
        self.id = UUID()
        self.url = url
        self.createdAt = createdAt
        self.filename = url.lastPathComponent
    }

    // Equality and hashing are URL-based so dedup works correctly
    public static func == (lhs: Screenshot, rhs: Screenshot) -> Bool {
        lhs.url == rhs.url
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}
