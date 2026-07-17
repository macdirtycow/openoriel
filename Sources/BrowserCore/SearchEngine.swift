import Foundation

enum SearchEngine: String, CaseIterable, Identifiable, Codable, Sendable {
    case duckDuckGo
    case google
    case bing
    case ecosia

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .duckDuckGo: "DuckDuckGo"
        case .google: "Google"
        case .bing: "Bing"
        case .ecosia: "Ecosia"
        }
    }

    var addressBarPlaceholder: String {
        "Search with \(displayName) or enter address"
    }

    var systemImage: String {
        switch self {
        case .duckDuckGo: "shield.lefthalf.filled"
        case .google: "globe"
        case .bing: "b.circle"
        case .ecosia: "leaf"
        }
    }

    func searchURL(for query: String) -> URL {
        var components: URLComponents
        switch self {
        case .duckDuckGo:
            components = URLComponents(string: "https://duckduckgo.com/")!
            components.queryItems = [URLQueryItem(name: "q", value: query)]
        case .google:
            components = URLComponents(string: "https://www.google.com/search")!
            components.queryItems = [URLQueryItem(name: "q", value: query)]
        case .bing:
            components = URLComponents(string: "https://www.bing.com/search")!
            components.queryItems = [URLQueryItem(name: "q", value: query)]
        case .ecosia:
            components = URLComponents(string: "https://www.ecosia.org/search")!
            components.queryItems = [URLQueryItem(name: "q", value: query)]
        }
        return components.url!
    }
}
