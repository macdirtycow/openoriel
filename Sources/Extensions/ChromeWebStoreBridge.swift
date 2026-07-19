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

      // Spoof desktop Chrome so CWS does not serve “not compatible with a phone”.
      var desktopUA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
      try {
        Object.defineProperty(navigator, 'userAgent', { configurable: true, get: function () { return desktopUA; } });
      } catch (e) {}
      try {
        Object.defineProperty(navigator, 'appVersion', {
          configurable: true,
          get: function () { return desktopUA.substring(8); }
        });
      } catch (e) {}
      try {
        Object.defineProperty(navigator, 'platform', { configurable: true, get: function () { return 'MacIntel'; } });
      } catch (e) {}
      try {
        Object.defineProperty(navigator, 'vendor', { configurable: true, get: function () { return 'Google Inc.'; } });
      } catch (e) {}
      try {
        Object.defineProperty(navigator, 'maxTouchPoints', { configurable: true, get: function () { return 0; } });
      } catch (e) {}
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

      function normalizeLabel(t) {
        return (t || '').replace(/\s+/g, ' ').trim();
      }
      function isInstallChromeLabel(t) {
        t = normalizeLabel(t);
        if (!t || t.length > 64) return false;
        if (/oriel/i.test(t)) return false;
        if (/remove|verwijder|entfernen|supprimer|quitar/i.test(t)) return false;
        // EN
        if (/^(Add to|Get) (Chrome|Brave)$/i.test(t)) return true;
        // NL (incl. abbreviated “Toev. aan Chrome”)
        if (/^(Toevoegen|Toev\.?)\s+aan\s+(Chrome|Brave)$/i.test(t)) return true;
        // DE / FR / ES / IT / PT
        if (/^Zu (Chrome|Brave) hinzufügen$/i.test(t)) return true;
        if (/^Ajouter à (Chrome|Brave)$/i.test(t)) return true;
        if (/^(Añadir|Agregar) a (Chrome|Brave)$/i.test(t)) return true;
        if (/^Aggiungi a (Chrome|Brave)$/i.test(t)) return true;
        if (/^Adicionar ao (Chrome|Brave)$/i.test(t)) return true;
        // Loose fallback for localized install CTAs that still name Chrome/Brave
        if (/\b(Chrome|Brave)\b/i.test(t)
            && /(add to|toevoegen|toev\.?|hinzufügen|ajouter|añadir|agregar|aggiungi|adicionar)/i.test(t)) {
          return true;
        }
        return false;
      }
      function isInstalledChromeLabel(t) {
        t = normalizeLabel(t);
        if (!t || t.length > 64) return false;
        return /^(Added to|Toegevoegd aan|Zu .+ hinzugefügt) (Chrome|Brave)$/i.test(t)
          || /^(Added to Chrome|Toegevoegd aan Chrome)$/i.test(t);
      }
      function rewriteTextNodeOrLeaf(el, label) {
        if (!el) return false;
        if (el.nodeType === 3) {
          el.nodeValue = label;
          return true;
        }
        if (el.childElementCount === 0) {
          el.textContent = label;
          return true;
        }
        var kids = el.querySelectorAll('span, div, p, label');
        for (var i = 0; i < kids.length; i++) {
          var leaf = kids[i];
          if (leaf.childElementCount > 0) continue;
          var t = normalizeLabel(leaf.textContent);
          if (isInstallChromeLabel(t) || isInstalledChromeLabel(t)) {
            leaf.textContent = label;
            return true;
          }
        }
        // Last resort: replace whole control text (may drop icon children).
        var whole = normalizeLabel(el.textContent);
        if (isInstallChromeLabel(whole) || isInstalledChromeLabel(whole)) {
          el.textContent = label;
          return true;
        }
        return false;
      }
      function rewriteLabels() {
        var nodes = document.querySelectorAll(
          'button, a, div[role="button"], span[role="button"], [jsname], [data-test-id], [aria-label]'
        );
        for (var i = 0; i < nodes.length; i++) {
          var el = nodes[i];
          if (el.id === 'oriel-add-to-oriel' || el.id === 'oriel-cws-tip') continue;
          var aria = normalizeLabel(el.getAttribute('aria-label'));
          var title = normalizeLabel(el.getAttribute('title'));
          var text = normalizeLabel(el.textContent);
          var targetLabel = null;
          if (isInstallChromeLabel(text) || isInstallChromeLabel(aria) || isInstallChromeLabel(title)) {
            targetLabel = 'Add to Oriel';
          } else if (isInstalledChromeLabel(text) || isInstalledChromeLabel(aria) || isInstalledChromeLabel(title)) {
            targetLabel = 'Installed in Oriel';
          }
          if (!targetLabel) continue;
          if (aria && (isInstallChromeLabel(aria) || isInstalledChromeLabel(aria))) {
            el.setAttribute('aria-label', targetLabel);
          }
          if (title && (isInstallChromeLabel(title) || isInstalledChromeLabel(title))) {
            el.setAttribute('title', targetLabel);
          }
          rewriteTextNodeOrLeaf(el, targetLabel);
        }
      }

      function isPhoneIncompatText(text) {
        if (!text) return false;
        if (/Item currently unavailable/i.test(text)) return true;
        if (/not compatible with (a )?(phone|mobile|device)/i.test(text)) return true;
        if (/not available (on|for) (your )?(phone|mobile|device|ios|iphone|ipad)/i.test(text)) return true;
        if (/only (works|available) on (desktop|computer|chrome for (desktop|mac|windows))/i.test(text)) return true;
        if (/this (item|extension|theme) (is )?unavailable/i.test(text)) return true;
        if (/can.?t (be )?(install|add).{0,24}(phone|mobile|ios)/i.test(text)) return true;
        if (/requires? chrome (for )?(desktop|mac|windows)/i.test(text)) return true;
        return false;
      }

      function hideUnavailable() {
        if (!document.body) return;
        var candidates = document.querySelectorAll('div, section, span, p, h1, h2, h3, li');
        for (var i = 0; i < candidates.length; i++) {
          var el = candidates[i];
          if (el.getAttribute('data-oriel-hidden-unavailable') === '1') continue;
          if (el.id === 'oriel-add-to-oriel' || el.id === 'oriel-cws-tip') continue;
          if (el.childElementCount > 8) continue;
          var text = (el.textContent || '').replace(/\s+/g, ' ').trim();
          if (text.length < 12 || text.length > 220) continue;
          if (!isPhoneIncompatText(text)) continue;
          el.style.setProperty('display', 'none', 'important');
          el.setAttribute('data-oriel-hidden-unavailable', '1');
        }
      }

      function ensureTip() {
        var id = idFromPath();
        var tip = document.getElementById('oriel-cws-tip');
        if (!id) { if (tip) tip.remove(); return; }
        if (!tip) {
          tip = document.createElement('div');
          tip.id = 'oriel-cws-tip';
          tip.setAttribute('role', 'status');
          Object.assign(tip.style, {
            position: 'fixed', left: '12px', right: '12px', bottom: '72px', zIndex: '2147483645',
            padding: '10px 14px', borderRadius: '10px',
            background: 'rgba(26, 115, 232, 0.94)', color: '#fff',
            font: '600 13px/1.35 -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif',
            boxShadow: '0 6px 20px rgba(0,0,0,0.18)', textAlign: 'center',
            pointerEvents: 'none'
          });
          tip.textContent = 'Oriel can install this extension on iPhone and iPad — tap Add to Oriel.';
          (document.body || document.documentElement).appendChild(tip);
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
        var el = t.closest('button, a, div[role="button"], span[role="button"]');
        if (!el || el.id === 'oriel-add-to-oriel') return;
        var label = normalizeLabel(el.textContent);
        var aria = normalizeLabel(el.getAttribute('aria-label'));
        var title = normalizeLabel(el.getAttribute('title'));
        var isOriel = /add to oriel|toevoegen aan oriel|installed in oriel/i.test(label)
          || /add to oriel|toevoegen aan oriel/i.test(aria);
        var isChromeCTA = isInstallChromeLabel(label) || isInstallChromeLabel(aria) || isInstallChromeLabel(title);
        if (!isOriel && !isChromeCTA) return;
        if (Math.max(label.length, aria.length) > 64) return;
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
          if (idFromPath()) { hideUnavailable(); ensureTip(); ensureButton(); }
          else {
            var btn = document.getElementById('oriel-add-to-oriel');
            if (btn) btn.remove();
            var tip = document.getElementById('oriel-cws-tip');
            if (tip) tip.remove();
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
