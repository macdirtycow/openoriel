import Foundation

enum ChromeWebStoreAPI {
    /// Chrome extension IDs are 32 characters from a–p.
    static func isValidExtensionID(_ id: String) -> Bool {
        id.count == 32 && id.unicodeScalars.allSatisfy { ("a"..."p").contains(Character($0)) }
    }

    static func extensionID(fromStoreURL url: URL) -> String? {
        let parts = url.path.split(separator: "/").map(String.init)
        return parts.last(where: isValidExtensionID(_:))
    }

    /// Public Chrome Web Store CRX redirect used by Chromium browsers (including Brave).
    static func downloadURL(forExtensionID id: String) -> URL? {
        guard isValidExtensionID(id) else { return nil }
        var components = URLComponents(string: "https://clients2.google.com/service/update2/crx")!
        components.queryItems = [
            URLQueryItem(name: "response", value: "redirect"),
            URLQueryItem(name: "prodversion", value: "131.0.0.0"),
            URLQueryItem(name: "acceptformat", value: "crx3"),
            URLQueryItem(name: "x", value: "id=\(id)&installsource=ondemand&uc")
        ]
        return components.url
    }
}

/// Injected into Chrome Web Store pages so users see “Add to Oriel” and can install.
enum ChromeWebStoreBridge {
    static let handlerName = "orielInstallExtension"

    static let userScriptSource = #"""
    (function () {
      if (window.__orielChromeWebStoreBridge) return;
      window.__orielChromeWebStoreBridge = true;

      function isStoreHost() {
        var h = location.hostname;
        return h === 'chromewebstore.google.com'
          || h === 'chrome.google.com'
          || h.endsWith('.chrome.google.com');
      }
      if (!isStoreHost()) return;

      function validId(id) {
        return typeof id === 'string' && /^[a-p]{32}$/.test(id);
      }

      function idFromPath() {
        var parts = location.pathname.split('/').filter(Boolean);
        for (var i = parts.length - 1; i >= 0; i--) {
          if (validId(parts[i])) return parts[i];
        }
        return null;
      }

      function postInstall(id) {
        try {
          window.webkit.messageHandlers.orielInstallExtension.postMessage({ id: id, source: location.href });
        } catch (e) {}
      }

      function rewriteTextNodes(root) {
        var walker = document.createTreeWalker(root || document.body, NodeFilter.SHOW_TEXT, null);
        var node;
        while ((node = walker.nextNode())) {
          if (node.nodeValue && /Add to (Chrome|Brave)/i.test(node.nodeValue)) {
            node.nodeValue = node.nodeValue.replace(/Add to (Chrome|Brave)/gi, 'Add to Oriel');
          }
        }
      }

      function ensureFloatingButton() {
        var id = idFromPath();
        var btn = document.getElementById('oriel-add-to-oriel');
        if (!id) {
          if (btn) btn.remove();
          return;
        }
        if (!btn) {
          btn = document.createElement('button');
          btn.id = 'oriel-add-to-oriel';
          btn.type = 'button';
          btn.textContent = 'Add to Oriel';
          btn.setAttribute('aria-label', 'Add to Oriel');
          Object.assign(btn.style, {
            position: 'fixed',
            right: '20px',
            bottom: '20px',
            zIndex: '2147483646',
            padding: '12px 18px',
            border: '0',
            borderRadius: '10px',
            background: '#243d42',
            color: '#f4f1ec',
            font: '600 14px -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif',
            cursor: 'pointer',
            boxShadow: '0 6px 20px rgba(0,0,0,0.22)'
          });
          btn.addEventListener('click', function (event) {
            event.preventDefault();
            event.stopPropagation();
            var current = idFromPath();
            if (!current) return;
            btn.disabled = true;
            btn.textContent = 'Installing…';
            postInstall(current);
            setTimeout(function () {
              btn.disabled = false;
              btn.textContent = 'Add to Oriel';
            }, 5000);
          }, true);
          (document.body || document.documentElement).appendChild(btn);
        }
      }

      function installClickCapture(event) {
        var target = event.target;
        if (!target || !target.closest) return;
        var el = target.closest('button, a, div[role="button"], span[role="button"]');
        if (!el) return;
        var text = (el.innerText || el.textContent || '').replace(/\s+/g, ' ').trim();
        if (!/Add to (Chrome|Brave|Oriel)/i.test(text)) return;
        var id = idFromPath();
        if (!id) return;
        event.preventDefault();
        event.stopPropagation();
        if (typeof event.stopImmediatePropagation === 'function') event.stopImmediatePropagation();
        postInstall(id);
      }

      function refresh() {
        rewriteTextNodes(document.body);
        ensureFloatingButton();
      }

      document.addEventListener('click', installClickCapture, true);
      refresh();
      var obs = new MutationObserver(function () { refresh(); });
      obs.observe(document.documentElement, { childList: true, subtree: true, characterData: true });
      window.addEventListener('popstate', refresh);
      setInterval(refresh, 1500);
    })();
    """#
}
