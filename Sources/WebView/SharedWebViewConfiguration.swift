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
        fingerprintingProtection: Bool = true,
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

        #if os(iOS)
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        #endif

        let ucc = configuration.userContentController
        if fingerprintingProtection {
            ucc.addUserScript(
                WKUserScript(
                    source: FingerprintingProtectionScript.source,
                    injectionTime: .atDocumentStart,
                    forMainFrameOnly: false,
                    in: .page
                )
            )
        }
        if contentBlockingEnabled {
            for list in contentRuleLists {
                ucc.add(list)
            }
            ucc.addUserScript(
                WKUserScript(
                    source: YouTubeAdBlockScript.source,
                    injectionTime: .atDocumentStart,
                    forMainFrameOnly: false,
                    in: .page
                )
            )
            ucc.addUserScript(
                WKUserScript(
                    source: AdvancedPageCleanupScript.documentStartSource,
                    injectionTime: .atDocumentStart,
                    forMainFrameOnly: true,
                    in: .page
                )
            )
            ucc.addUserScript(
                WKUserScript(
                    source: AdvancedPageCleanupScript.source,
                    injectionTime: .atDocumentEnd,
                    forMainFrameOnly: true,
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
        #elseif os(iOS)
        if #available(iOS 18.4, *),
           !isPrivate,
           let controller = webExtensionController as? WKWebExtensionController {
            configuration.webExtensionController = controller
        }
        #endif

        return configuration
    }
}
