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

    /// Runs at document start in the page world so the store’s own scripts see Chrome APIs.
    static let chromeAPIStubSource = #"""
    (function () {
      if (window.__orielChromeAPIStub) return;
      window.__orielChromeAPIStub = true;

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
        if (!validId(id)) return;
        try {
          window.webkit.messageHandlers.orielInstallExtension.postMessage({
            id: id,
            source: location.href
          });
        } catch (e) {}
      }

      // Make the page look like Chromium so CWS enables install UI.
      try {
        Object.defineProperty(navigator, 'userAgentData', {
          configurable: true,
          get: function () {
            return {
              brands: [
                { brand: 'Chromium', version: '131' },
                { brand: 'Google Chrome', version: '131' },
                { brand: 'Not_A Brand', version: '24' }
              ],
              mobile: false,
              platform: 'macOS',
              getHighEntropyValues: function () {
                return Promise.resolve({
                  architecture: 'arm',
                  bitness: '64',
                  brands: this.brands,
                  fullVersionList: [
                    { brand: 'Chromium', version: '131.0.0.0' },
                    { brand: 'Google Chrome', version: '131.0.0.0' },
                    { brand: 'Not_A Brand', version: '10.0.0.0' }
                  ],
                  mobile: false,
                  model: '',
                  platform: 'macOS',
                  platformVersion: '14.0.0',
                  uaFullVersion: '131.0.0.0'
                });
              },
              toJSON: function () {
                return { brands: this.brands, mobile: false, platform: 'macOS' };
              }
            };
          }
        });
      } catch (e) {}

      var chromeObj = window.chrome || {};
      window.chrome = chromeObj;
      chromeObj.runtime = chromeObj.runtime || {
        id: undefined,
        getManifest: function () { return undefined; },
        connect: function () {
          return { onMessage: { addListener: function () {} }, postMessage: function () {}, disconnect: function () {} };
        },
        sendMessage: function () {}
      };

      chromeObj.webstorePrivate = {
        getExtensionStatus: function (id, manifest, cb) {
          if (typeof manifest === 'function') { cb = manifest; }
          if (typeof cb === 'function') cb('installable');
        },
        beginInstallWithManifest3: function (extinfo, cb) {
          var id = null;
          if (typeof extinfo === 'string') id = extinfo;
          else if (extinfo && typeof extinfo.id === 'string') id = extinfo.id;
          if (!id) id = idFromPath();
          postInstall(id);
          // Cancel Chromium’s install flow; Oriel handles the CRX download itself.
          if (typeof cb === 'function') cb('user_cancelled');
        },
        isInIncognitoMode: function (cb) { if (typeof cb === 'function') cb(false); },
        getReferrerChain: function (cb) { if (typeof cb === 'function') cb('EgIIAA=='); },
        completeInstall: function (id, cb) { if (typeof cb === 'function') cb(true); }
      };

      chromeObj.management = chromeObj.management || {
        getAll: function (cb) { if (typeof cb === 'function') cb([]); },
        get: function (id, cb) { if (typeof cb === 'function') cb(null); },
        setEnabled: function (id, enabled, cb) { if (typeof cb === 'function') cb(); },
        uninstall: function (id, options, cb) {
          if (typeof options === 'function') { cb = options; }
          if (typeof cb === 'function') cb();
        },
        onInstalled: { addListener: function () {} },
        onUninstalled: { addListener: function () {} }
      };
    })();
    """#

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
        if (!validId(id)) return;
        try {
          window.webkit.messageHandlers.orielInstallExtension.postMessage({
            id: id,
            source: location.href
          });
        } catch (e) {}
      }

      function hideUnavailableBanners() {
        if (!document.body) return;
        var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null);
        var node;
        while ((node = walker.nextNode())) {
          var value = node.nodeValue || '';
          if (!/Item currently unavailable/i.test(value)) continue;
          var el = node.parentElement;
          for (var depth = 0; el && depth < 8; depth++) {
            var rect = el.getBoundingClientRect();
            var text = (el.innerText || '').trim();
            if (
              rect.height >= 24 &&
              rect.height <= 140 &&
              rect.width >= 240 &&
              text.length < 280 &&
              /Item currently unavailable/i.test(text)
            ) {
              el.style.setProperty('display', 'none', 'important');
              el.setAttribute('data-oriel-hidden-unavailable', '1');
              break;
            }
            el = el.parentElement;
          }
        }
      }

      function rewriteInstallLabels(root) {
        var walker = document.createTreeWalker(root || document.body, NodeFilter.SHOW_TEXT, null);
        var node;
        while ((node = walker.nextNode())) {
          if (node.nodeValue && /Add to (Chrome|Brave)/i.test(node.nodeValue)) {
            node.nodeValue = node.nodeValue.replace(/Add to (Chrome|Brave)/gi, 'Add to Oriel');
          }
        }
      }

      function isInstallControl(el) {
        if (!el || el.id === 'oriel-add-to-oriel') return false;
        var text = (el.innerText || el.textContent || '').replace(/\s+/g, ' ').trim();
        return /Add to (Chrome|Brave|Oriel)/i.test(text);
      }

      function unlockInstallControls() {
        var nodes = document.querySelectorAll('button, a, div[role="button"], span[role="button"]');
        for (var i = 0; i < nodes.length; i++) {
          var el = nodes[i];
          if (!isInstallControl(el)) continue;

          el.removeAttribute('disabled');
          el.removeAttribute('aria-disabled');
          el.disabled = false;
          el.setAttribute('aria-disabled', 'false');
          el.style.setProperty('pointer-events', 'auto', 'important');
          el.style.setProperty('opacity', '1', 'important');
          el.style.setProperty('cursor', 'pointer', 'important');
          el.style.removeProperty('filter');

          if (!el.dataset.orielInstallWired) {
            el.dataset.orielInstallWired = '1';
            el.addEventListener('click', function (event) {
              var id = idFromPath();
              if (!id) return;
              event.preventDefault();
              event.stopPropagation();
              if (typeof event.stopImmediatePropagation === 'function') {
                event.stopImmediatePropagation();
              }
              postInstall(id);
            }, true);
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
            background: '#1a73e8',
            color: '#ffffff',
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
        if (!el || el.id === 'oriel-add-to-oriel') return;
        if (!isInstallControl(el)) return;
        var id = idFromPath();
        if (!id) return;
        event.preventDefault();
        event.stopPropagation();
        if (typeof event.stopImmediatePropagation === 'function') event.stopImmediatePropagation();
        postInstall(id);
      }

      function refresh() {
        if (!document.body) return;
        hideUnavailableBanners();
        rewriteInstallLabels(document.body);
        unlockInstallControls();
        ensureFloatingButton();
      }

      document.addEventListener('click', installClickCapture, true);
      document.addEventListener('pointerdown', installClickCapture, true);
      refresh();
      var obs = new MutationObserver(function () { refresh(); });
      obs.observe(document.documentElement, {
        childList: true,
        subtree: true,
        characterData: true,
        attributes: true,
        attributeFilter: ['disabled', 'aria-disabled', 'class', 'style']
      });
      window.addEventListener('popstate', refresh);
      setInterval(refresh, 800);
    })();
    """#
}
