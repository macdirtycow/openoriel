import Foundation
import Observation

@Observable
@MainActor
final class HistoryStore {
    private(set) var entries: [HistoryEntry] = []
    private let fileName = "history.json"
    private let maxEntries = 500

    init() {
        load()
    }

    /// Recent non-start-page visits for the start page.
    var recentSites: [HistoryEntry] {
        var seen = Set<String>()
        var result: [HistoryEntry] = []
        for entry in entries {
            guard let url = entry.url, !URLParser.isStartPage(url) else { continue }
            let key = url.host ?? entry.urlString
            if seen.insert(key).inserted {
                result.append(entry)
            }
            if result.count >= 12 { break }
        }
        return result
    }

    /// Grouped newest-first by calendar day.
    var groupedByDay: [(day: Date, entries: [HistoryEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.visitedAt)
        }
        return grouped.keys.sorted(by: >).map { day in
            (day, grouped[day]?.sorted { $0.visitedAt > $1.visitedAt } ?? [])
        }
    }

    func record(title: String, url: URL) {
        guard !URLParser.isStartPage(url) else { return }
        guard url.scheme == "http" || url.scheme == "https" else { return }

        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = HistoryEntry(
            title: trimmed.isEmpty ? (url.host ?? url.absoluteString) : trimmed,
            url: url
        )
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        persist()
    }

    func search(_ query: String) -> [HistoryEntry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return entries }
        return entries.filter {
            $0.title.lowercased().contains(q) || $0.urlString.lowercased().contains(q)
        }
    }

    func clear(olderThan date: Date? = nil) {
        if let date {
            entries.removeAll { $0.visitedAt < date }
        } else {
            entries.removeAll()
        }
        persist()
    }

    func clearLastHour() {
        clear(olderThan: Date().addingTimeInterval(-3600))
    }

    func clearLastDay() {
        clear(olderThan: Date().addingTimeInterval(-86_400))
    }

    private func load() {
        do {
            if let loaded = try JSONFileStore.load([HistoryEntry].self, from: fileName) {
                entries = loaded
            }
        } catch {
            entries = []
        }
    }

    private func persist() {
        try? JSONFileStore.save(entries, to: fileName)
    }
}
