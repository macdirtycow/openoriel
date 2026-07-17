import Foundation

struct Bookmark: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID
    var title: String
    var urlString: String
    var createdAt: Date

    var url: URL? { URL(string: urlString) }

    init(id: UUID = UUID(), title: String, url: URL, createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.urlString = url.absoluteString
        self.createdAt = createdAt
    }
}
