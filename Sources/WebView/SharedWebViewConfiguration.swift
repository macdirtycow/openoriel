import Foundation
import WebKit

/// Shared WebKit plumbing so tabs can share process state (needed for web extensions).
enum SharedWebViewConfiguration {
    static let processPool = WKProcessPool()

    @MainActor
    static func make(
        isPrivate: Bool,
        javaScriptEnabled: Bool,
        contentRuleLists: [WKContentRuleList],
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

        let ucc = configuration.userContentController
        if contentBlockingEnabled {
            for list in contentRuleLists {
                ucc.add(list)
            }
            // Early YouTube skip/hide — host check is inside the script.
            ucc.addUserScript(
                WKUserScript(
                    source: YouTubeAdBlockScript.source,
                    injectionTime: .atDocumentStart,
                    forMainFrameOnly: false,
                    in: .page
                )
            )
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
