import Foundation

struct HistoryEntry: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID
    var title: String
    var urlString: String
    var visitedAt: Date

    var url: URL? { URL(string: urlString) }

    init(id: UUID = UUID(), title: String, url: URL, visitedAt: Date = .now) {
        self.id = id
        self.title = title
        self.urlString = url.absoluteString
        self.visitedAt = visitedAt
    }
}
