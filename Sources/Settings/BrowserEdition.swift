import Foundation
import SwiftUI

/// In-app browser edition — same binary, different chrome and feature emphasis.
enum BrowserEdition: String, CaseIterable, Identifiable, Codable, Sendable {
    case classic
    case pulse

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: "Oriel"
        case .pulse: "Oriel Pulse"
        }
    }

    var shortLabel: String {
        switch self {
        case .classic: "Classic"
        case .pulse: "Pulse"
        }
    }

    var tagline: String {
        switch self {
        case .classic: "A calm view of the web."
        case .pulse: "Built for play. Still private."
        }
    }

    var subtitle: String {
        switch self {
        case .classic: "Calm chrome and everyday browsing."
        case .pulse: "Gaming-inspired chrome with performance controls."
        }
    }

    var systemImage: String {
        switch self {
        case .classic: "circle.lefthalf.filled"
        case .pulse: "bolt.horizontal.circle.fill"
        }
    }

    /// Suggested accent when switching into this edition (user can still change later).
    var preferredAccent: BrowserAccentTheme {
        switch self {
        case .classic: .teal
        case .pulse: .ocean
        }
    }

    var preferredBackground: BrowserBackgroundTheme {
        switch self {
        case .classic: .soft
        case .pulse: .midnight
        }
    }

    var isPulse: Bool { self == .pulse }
}

enum EditionBranding {
    static func productName(for edition: BrowserEdition) -> String {
        edition.displayName
    }

    static func tagline(for edition: BrowserEdition) -> String {
        edition.tagline
    }

    /// Pulse accent — electric cyan that reads well on midnight chrome.
    static let pulseAccent = Color(red: 0.20, green: 0.92, blue: 0.88)
    static let pulseAccentSoft = Color(red: 0.45, green: 0.98, blue: 0.94)
    static let pulseMagenta = Color(red: 0.92, green: 0.28, blue: 0.62)
    static let pulseNavy = Color(red: 0.06, green: 0.08, blue: 0.16)
}
