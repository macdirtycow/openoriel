import Foundation

enum ChromeWebStoreAPI {
    /// Custom scheme used when `webkit.messageHandlers` is unavailable in the page world.
    static let installURLScheme = "oriel-extension"

    /// Chrome extension IDs are 32 characters from a–p.
    static func isValidExtensionID(_ id: String) -> Bool {
        id.count == 32 && id.unicodeScalars.allSatisfy { ("a"..."p").contains(Character($0)) }
    }

    static func extensionID(fromStoreURL url: URL) -> String? {
        let parts = url.path.split(separator: "/").map(String.init)
        return parts.last(where: isValidExtensionID(_:))
    }

    /// `oriel-extension://install/<id>`
    static func extensionID(fromInstallURL url: URL) -> String? {
        guard url.scheme?.lowercased() == installURLScheme else { return nil }
        if url.host?.lowercased() == "manage" { return nil }
        if let host = url.host?.lowercased(), isValidExtensionID(host) {
            return host
        }
        let parts = url.path.split(separator: "/").map { $0.lowercased() }
        return parts.last(where: isValidExtensionID)
    }

    static func isManageExtensionsURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == installURLScheme else { return false }
        return url.host?.lowercased() == "manage"
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

    static func installURL(forExtensionID id: String) -> URL? {
        guard isValidExtensionID(id) else { return nil }
        return URL(string: "\(installURLScheme)://install/\(id)")
    }
}

/// Injected into Chrome Web Store pages so users see “Add to Oriel” and can install.
enum ChromeWebStoreBridge {
    static let handlerName = "orielInstallExtension"

    /// Document-start stub so the store enables its install UI.
    static let chromeAPIStubSource = #"""
    (function () {
      if (window.__orielChromeAPIStub) return;
      window.__orielChromeAPIStub = true;
      var h = location.hostname;
      if (h !== 'chromewebstore.google.com' && h !== 'chrome.google.com' && !h.endsWith('.chrome.google.com')) return;

      window.__orielInstalledExtensionIDs = window.__orielInstalledExtensionIDs || [];

      function validId(id) { return typeof id === 'string' && /^[a-p]{32}$/.test(id); }
      function idFromPath() {
        var parts = location.pathname.split('/').filter(Boolean);
        for (var i = parts.length - 1; i >= 0; i--) if (validId(parts[i])) return parts[i];
        return null;
      }
      function postInstall(id) {
        if (!validId(id)) return;
        try {
          if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.orielInstallExtension) {
            window.webkit.messageHandlers.orielInstallExtension.postMessage(String(id));
            return;
          }
        } catch (e) {}
        try {
          var a = document.createElement('a');
          a.href = 'oriel-extension://install/' + id;
          a.rel = 'noreferrer';
          a.style.display = 'none';
          document.documentElement.appendChild(a);
          a.click();
          a.remove();
        } catch (e2) {}
      }
      window.__orielPostInstall = postInstall;

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
                  architecture: 'arm', bitness: '64', brands: this.brands,
                  fullVersionList: [
                    { brand: 'Chromium', version: '131.0.0.0' },
                    { brand: 'Google Chrome', version: '131.0.0.0' },
                    { brand: 'Not_A Brand', version: '10.0.0.0' }
                  ],
                  mobile: false, model: '', platform: 'macOS',
                  platformVersion: '14.0.0', uaFullVersion: '131.0.0.0'
                });
              }
            };
          }
        });
      } catch (e) {}

      var chromeObj = window.chrome || {};
      window.chrome = chromeObj;
      chromeObj.runtime = chromeObj.runtime || { id: undefined, getManifest: function () {}, connect: function () { return { onMessage: { addListener: function () {} }, postMessage: function () {}, disconnect: function () {} }; }, sendMessage: function () {} };
      chromeObj.webstorePrivate = {
        getExtensionStatus: function (id, manifest, cb) {
          if (typeof manifest === 'function') cb = manifest;
          var installed = window.__orielInstalledExtensionIDs || [];
          if (id && installed.indexOf(String(id).toLowerCase()) !== -1) { if (cb) cb('enabled'); return; }
          if (cb) cb('installable');
        },
        beginInstallWithManifest3: function (extinfo, cb) {
          var id = typeof extinfo === 'string' ? extinfo : (extinfo && extinfo.id) || idFromPath();
          var installed = window.__orielInstalledExtensionIDs || [];
          if (id && installed.indexOf(String(id).toLowerCase()) !== -1) {
            try {
              var a = document.createElement('a');
              a.href = 'oriel-extension://manage';
              a.style.display = 'none';
              document.documentElement.appendChild(a);
              a.click();
              a.remove();
            } catch (e) {}
          } else {
            postInstall(id);
          }
          if (cb) cb('user_cancelled');
        },
        isInIncognitoMode: function (cb) { if (cb) cb(false); },
        getReferrerChain: function (cb) { if (cb) cb('EgIIAA=='); },
        completeInstall: function (id, cb) { if (cb) cb(true); }
      };
      chromeObj.management = {
        getAll: function (cb) {
          var installed = window.__orielInstalledExtensionIDs || [];
          if (cb) cb(installed.map(function (extId) { return { id: extId, enabled: true, type: 'extension' }; }));
        },
        get: function (id, cb) { if (cb) cb(null); },
        setEnabled: function (id, enabled, cb) { if (cb) cb(); },
        uninstall: function (id, options, cb) { if (typeof options === 'function') cb = options; if (cb) cb(); },
        onInstalled: { addListener: function () {} },
        onUninstalled: { addListener: function () {} }
      };
    })();
    """#

    /// Lightweight DOM bridge — labels + one floating install button (page world).
    static let userScriptSource = #"""
    (function () {
      if (window.__orielChromeWebStoreBridge) return;
      window.__orielChromeWebStoreBridge = true;
      var h = location.hostname;
      if (h !== 'chromewebstore.google.com' && h !== 'chrome.google.com' && !h.endsWith('.chrome.google.com')) return;

      function validId(id) { return typeof id === 'string' && /^[a-p]{32}$/.test(id); }
      function idFromPath() {
        var parts = location.pathname.split('/').filter(Boolean);
        for (var i = parts.length - 1; i >= 0; i--) if (validId(parts[i])) return parts[i];
        return null;
      }
      function postInstall(id) {
        if (typeof window.__orielPostInstall === 'function') {
          window.__orielPostInstall(id);
          return;
        }
        try {
          window.webkit.messageHandlers.orielInstallExtension.postMessage(String(id));
        } catch (e) {
          try {
            var a = document.createElement('a');
            a.href = 'oriel-extension://install/' + id;
            a.style.display = 'none';
            document.documentElement.appendChild(a);
            a.click();
            a.remove();
          } catch (e2) {}
        }
      }
      function isInstalled(id) {
        return id && (window.__orielInstalledExtensionIDs || []).indexOf(id) !== -1;
      }
      function openManage() {
        try {
          var a = document.createElement('a');
          a.href = 'oriel-extension://manage';
          a.style.display = 'none';
          document.documentElement.appendChild(a);
          a.click();
          a.remove();
        } catch (e) {}
      }

      var scheduled = null;
      var busy = false;

      function rewriteLabels() {
        var nodes = document.querySelectorAll('button, div[role="button"], span');
        for (var i = 0; i < nodes.length; i++) {
          var el = nodes[i];
          if (el.id === 'oriel-add-to-oriel') continue;
          if (el.childElementCount > 0) continue;
          var t = (el.textContent || '').replace(/\s+/g, ' ').trim();
          if (/^Add to (Chrome|Brave)$/i.test(t)) el.textContent = 'Add to Oriel';
        }
      }

      function hideUnavailable() {
        if (!document.body) return;
        var candidates = document.querySelectorAll('div, section, span, p');
        for (var i = 0; i < candidates.length; i++) {
          var el = candidates[i];
          if (el.getAttribute('data-oriel-hidden-unavailable') === '1') continue;
          if (el.childElementCount > 6) continue;
          var text = (el.textContent || '').replace(/\s+/g, ' ').trim();
          if (text.length < 20 || text.length > 180) continue;
          if (!/Item currently unavailable/i.test(text)) continue;
          el.style.setProperty('display', 'none', 'important');
          el.setAttribute('data-oriel-hidden-unavailable', '1');
        }
      }

      function ensureButton() {
        var id = idFromPath();
        var btn = document.getElementById('oriel-add-to-oriel');
        if (!id) { if (btn) btn.remove(); return; }
        var installed = isInstalled(id);
        if (!btn) {
          btn = document.createElement('button');
          btn.id = 'oriel-add-to-oriel';
          btn.type = 'button';
          Object.assign(btn.style, {
            position: 'fixed', right: '20px', bottom: '20px', zIndex: '2147483646',
            padding: '12px 18px', border: '0', borderRadius: '10px',
            color: '#fff', cursor: 'pointer',
            font: '600 14px -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif',
            boxShadow: '0 6px 20px rgba(0,0,0,0.22)'
          });
          btn.addEventListener('click', function (event) {
            event.preventDefault();
            event.stopPropagation();
            var current = idFromPath();
            if (!current) return;
            if (isInstalled(current)) { openManage(); return; }
            btn.disabled = true;
            btn.textContent = 'Installing…';
            postInstall(current);
            setTimeout(function () {
              btn.disabled = false;
              var done = isInstalled(current);
              btn.textContent = done ? 'Installed in Oriel' : 'Add to Oriel';
              btn.style.background = done ? '#5f6368' : '#1a73e8';
            }, 4500);
          }, true);
          (document.body || document.documentElement).appendChild(btn);
        }
        btn.textContent = installed ? 'Installed in Oriel' : 'Add to Oriel';
        btn.style.background = installed ? '#5f6368' : '#1a73e8';
      }

      function onClick(event) {
        var t = event.target;
        if (!t || !t.closest) return;
        var el = t.closest('button, a, div[role="button"]');
        if (!el || el.id === 'oriel-add-to-oriel') return;
        var label = (el.textContent || '').replace(/\s+/g, ' ').trim();
        if (!/Add to (Chrome|Brave|Oriel)/i.test(label)) return;
        // Ignore huge containers that merely contain the phrase.
        if (label.length > 40) return;
        var id = idFromPath();
        if (!id) return;
        event.preventDefault();
        event.stopPropagation();
        if (event.stopImmediatePropagation) event.stopImmediatePropagation();
        if (isInstalled(id)) openManage();
        else postInstall(id);
      }

      function refresh() {
        if (busy || !document.body) return;
        busy = true;
        try {
          rewriteLabels();
          if (idFromPath()) { hideUnavailable(); ensureButton(); }
          else {
            var btn = document.getElementById('oriel-add-to-oriel');
            if (btn) btn.remove();
          }
        } finally { busy = false; }
      }
      function schedule() {
        if (scheduled != null) return;
        scheduled = setTimeout(function () { scheduled = null; refresh(); }, 300);
      }

      document.addEventListener('click', onClick, true);
      refresh();
      new MutationObserver(function () { if (!busy) schedule(); })
        .observe(document.documentElement, { childList: true, subtree: true });
      var path = location.pathname;
      setInterval(function () {
        if (location.pathname !== path) { path = location.pathname; schedule(); }
      }, 1000);
    })();
    """#
}
