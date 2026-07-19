import SwiftUI

/// Shared layout helpers for iPhone / iPad / Mac chrome.
enum OrielLayout {
    static let phoneChromePadding: CGFloat = 12
    static let padChromePadding: CGFloat = 14
    static let macChromePadding: CGFloat = 12
    static let navButtonSize: CGFloat = 40
    static let compactNavButtonSize: CGFloat = 36
    /// Visual weight for iPhone bottom toolbar icons (hit target stays ~44 via button style).
    static let phoneToolbarIconSize: CGFloat = 21
    /// Shared tab-chip corner radius (iPad strip + Mac strips).
    static let tabChipRadius: CGFloat = 10
    static let startPageMaxWidthCompact: CGFloat = 560
    static let startPageMaxWidthRegular: CGFloat = 880
    static let startPageGutterCompact: CGFloat = 20
    static let startPageGutterRegular: CGFloat = 36
    static let profileChipMaxWidth: CGFloat = 120
    /// Phone bottom chrome vertical rhythm.
    static let phoneChromeStackSpacing: CGFloat = 8
    static let phoneChromeTopPadding: CGFloat = 8
    static let phoneChromeBottomPadding: CGFloat = 6
}
