import Foundation

/// Built-in workspace templates inspired by gaming-browser “modes”.
enum WorkspacePreset: String, CaseIterable, Identifiable, Sendable {
    case play
    case stream
    case focus

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .play: "Play"
        case .stream: "Stream"
        case .focus: "Focus"
        }
    }

    var subtitle: String {
        switch self {
        case .play: "Gaming sites + Pulse limits"
        case .stream: "Twitch / YouTube + split-friendly"
        case .focus: "Fewer engines, data saver on"
        }
    }

    var systemImage: String {
        switch self {
        case .play: "gamecontroller"
        case .stream: "dot.radiowaves.left.and.right"
        case .focus: "target"
        }
    }

    /// Seed URLs opened as tabs when creating the preset workspace.
    var seedURLs: [URL] {
        switch self {
        case .play:
            return [
                URL(string: "https://www.twitch.tv")!,
                URL(string: "https://store.steampowered.com")!,
                URL(string: "https://discord.com/app")!
            ]
        case .stream:
            return [
                URL(string: "https://www.twitch.tv")!,
                URL(string: "https://www.youtube.com")!,
                URL(string: "https://dashboard.twitch.tv")!
            ]
        case .focus:
            return [
                URL(string: "https://duckduckgo.com")!
            ]
        }
    }

    var prefersPulse: Bool { true }

    var webViewLimit: Int {
        switch self {
        case .play: 8
        case .stream: 6
        case .focus: 4
        }
    }

    var dataSaver: Bool {
        self == .focus
    }

    var verticalTabs: Bool {
        self == .stream || self == .play
    }
}
