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
        case .pulse: "Dark studio chrome with performance controls."
        }
    }

    var systemImage: String {
        switch self {
        case .classic: "circle.lefthalf.filled"
        case .pulse: "square.split.2x2.fill"
        }
    }

    /// Suggested accent when switching into this edition (user can still change later).
    var preferredAccent: BrowserAccentTheme {
        switch self {
        case .classic: .teal
        case .pulse: .slate
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

    /// Shared product-title type for start page, About, and onboarding (Classic + Pulse).
    static func productTitleFont(for edition: BrowserEdition, size: CGFloat) -> Font {
        if edition.isPulse {
            // Heavy default face — not rounded “toy” gaming type.
            return .system(size: size, weight: .heavy, design: .default)
        }
        return .system(size: size, weight: .semibold, design: .serif)
    }

    static func productTitleTracking(for edition: BrowserEdition) -> CGFloat {
        edition.isPulse ? -1.1 : -0.7
    }

    /// Small caps eyebrow above the Pulse wordmark.
    static func pulseEyebrowFont(size: CGFloat = 11) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    static let pulseEyebrowTracking: CGFloat = 3.2

    // MARK: Pulse palette — obsidian studio + single vermillion signal (no neon cyan/magenta)

    /// Deep ink used for Pulse marks and midnight wash.
    static let pulseNavy = Color(red: 0.043, green: 0.047, blue: 0.059)
    /// Primary Pulse accent — vermillion signal.
    static let pulseAccent = Color(red: 1.0, green: 0.29, blue: 0.17)
    static let pulseAccentSoft = Color(red: 1.0, green: 0.48, blue: 0.36)
    /// Cool steel for mullions / secondary chrome.
    static let pulseSteel = Color(red: 0.73, green: 0.75, blue: 0.80)
    /// Kept for wallpaper warmth only (not a second brand color on chrome).
    static let pulseMagenta = Color(red: 0.86, green: 0.28, blue: 0.22)
}
