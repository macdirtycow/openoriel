import Foundation

enum BookmarkHTMLImporter {
    struct ImportedBookmark: Equatable {
        var title: String
        var url: URL
    }

    /// Parses Netscape-bookmark HTML exports (Chrome, Firefox, Safari, Brave, Opera).
    static func parse(_ html: String) -> [ImportedBookmark] {
        var results: [ImportedBookmark] = []
        // <A HREF="url" ...>title</A>
        let pattern = #"<a[^>]*href=["']([^"']+)["'][^>]*>(.*?)</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        regex.enumerateMatches(in: html, options: [], range: range) { match, _, _ in
            guard let match,
                  let urlRange = Range(match.range(at: 1), in: html),
                  let titleRange = Range(match.range(at: 2), in: html),
                  let url = URL(string: String(html[urlRange])),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https"
            else { return }
            let rawTitle = String(html[titleRange])
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let title = rawTitle.isEmpty ? (url.host ?? url.absoluteString) : rawTitle
            results.append(ImportedBookmark(title: title, url: url))
        }
        return results
    }
}
