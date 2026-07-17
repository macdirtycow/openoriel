import Foundation
import WebKit

/// Shared WebKit plumbing so tabs can share process state (needed for web extensions).
enum SharedWebViewConfiguration {
    static let processPool = WKProcessPool()

    @MainActor
    static func make(
        isPrivate: Bool,
        javaScriptEnabled: Bool,
        contentRuleList: WKContentRuleList?,
        contentBlockingEnabled: Bool,
        blockAutoplay: Bool = true,
        webExtensionController: AnyObject? = nil
    ) -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.processPool = processPool
        configuration.websiteDataStore = isPrivate ? .nonPersistent() : .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = javaScriptEnabled
        configuration.preferences.isElementFullscreenEnabled = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        if blockAutoplay {
            configuration.mediaTypesRequiringUserActionForPlayback = [.all]
        } else {
            configuration.mediaTypesRequiringUserActionForPlayback = []
        }

        if contentBlockingEnabled, let contentRuleList {
            configuration.userContentController.add(contentRuleList)
        }

        #if os(macOS)
        if #available(macOS 15.4, *),
           !isPrivate,
           let controller = webExtensionController as? WKWebExtensionController {
            configuration.webExtensionController = controller
        }
        #endif

        return configuration
    }
}
