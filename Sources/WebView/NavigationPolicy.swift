import Foundation
import WebKit

enum NavigationPolicy {
    struct Context {
        var contentBlockingEnabled: Bool = true
        var matchesBlockedHint: (URL) -> Bool = { _ in false }
        var onBlocked: () -> Void = {}
    }

    /// Decides whether a navigation request may proceed.
    static func decision(
        for navigationAction: WKNavigationAction,
        context: Context = Context()
    ) -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else {
            return .cancel
        }

        guard let scheme = url.scheme?.lowercased() else {
            return .cancel
        }

        if URLParser.rejectedSchemes.contains(scheme) {
            return .cancel
        }

        if context.contentBlockingEnabled,
           navigationAction.targetFrame?.isMainFrame == false,
           context.matchesBlockedHint(url) {
            context.onBlocked()
            return .cancel
        }

        if URLParser.allowedSchemes.contains(scheme) {
            if scheme == BrowserConstants.aboutScheme {
                return .cancel
            }
            return .allow
        }

        return .cancel
    }
}
