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
      window.__orielInstalledFirefoxSlugs = window.__orielInstalledFirefoxSlugs || [];

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

      // Spoof desktop Chrome *APIs / navigator* so install CTAs appear.
      // Layout stays phone-width via StoreReadableLayout (CWS .IqBfM min-width override)
      // + iOS preferredContentMode=.mobile — do not set customUserAgent to Chrome desktop.
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

    /// DOM bridge — hide “desktop only”, rewrite native CTAs, sticky Install bar on detail pages.
    /// Readable layout stays in `StoreReadableLayout`; install does not need a Python proxy.
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

      function i18n() { return window.__orielStoreI18n || null; }
      function normalizeLabel(t) {
        var api = i18n();
        return api ? api.normalize(t) : (t || '').replace(/\s+/g, ' ').trim();
      }
      function isInstallChromeLabel(t) {
        var api = i18n();
        if (api && api.isChromeInstallLabel(t)) return true;
        t = normalizeLabel(t);
        // Theme CTAs on CWS sometimes omit the Chrome brand (“Add theme” / “Thema toevoegen”).
        if (/^(Add theme|Toevoegen thema|Thema toevoegen|Add to Chrome|Toevoegen aan Chrome)$/i.test(t)) return true;
        if (api) return false;
        return /\bChrome\b|\bBrave\b/i.test(t) && /add to|toevoegen|hinzufügen|ajouter/i.test(t);
      }
      function isInstalledChromeLabel(t) {
        var api = i18n();
        if (api) return api.isChromeInstalledLabel(t);
        return false;
      }
      function isRemoveChromeLabel(t) {
        var api = i18n();
        if (api && api.isChromeRemoveLabel) return api.isChromeRemoveLabel(t);
        t = normalizeLabel(t);
        return /verwijderen uit chrome|remove from chrome|aus chrome entfernen|supprimer de chrome|quitar de chrome/i.test(t);
      }
      function L(key) {
        var api = i18n();
        return api ? api.t(key) : ({
          add: 'Add to Oriel', addTheme: 'Add theme to Oriel', installing: 'Installing…',
          installed: 'Installed in Oriel', remove: 'Remove from Oriel',
          tipChrome: 'Oriel can install this extension on iPhone and iPad — tap Add to Oriel.'
        })[key] || key;
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
          if (isInstallChromeLabel(t) || isInstalledChromeLabel(t) || isRemoveChromeLabel(t)) {
            leaf.textContent = label;
            return true;
          }
        }
        var whole = normalizeLabel(el.textContent);
        if (isInstallChromeLabel(whole) || isInstalledChromeLabel(whole) || isRemoveChromeLabel(whole)) {
          el.textContent = label;
          return true;
        }
        return false;
      }
      function rewriteLabels() {
        var pageID = idFromPath();
        var pageInstalled = !!(pageID && isInstalled(pageID));
        var addLabel = L('add');
        var installedLabel = L('installed');
        var removeLabel = L('remove');
        var nodes = document.querySelectorAll(
          'button, a, div[role="button"], span[role="button"], [jsname], [data-test-id], [aria-label]'
        );
        for (var i = 0; i < nodes.length; i++) {
          var el = nodes[i];
          if (el.id === 'oriel-add-to-oriel' || el.id === 'oriel-install-bar' || el.id === 'oriel-cws-tip') continue;
          var aria = normalizeLabel(el.getAttribute('aria-label'));
          var title = normalizeLabel(el.getAttribute('title'));
          var text = normalizeLabel(el.textContent);
          var targetLabel = null;
          var looksRemove = isRemoveChromeLabel(text) || isRemoveChromeLabel(aria) || isRemoveChromeLabel(title)
            || text === removeLabel || aria === removeLabel;
          var looksInstall = isInstallChromeLabel(text) || isInstallChromeLabel(aria) || isInstallChromeLabel(title)
            || text === addLabel || aria === addLabel;
          var looksInstalled = isInstalledChromeLabel(text) || isInstalledChromeLabel(aria) || isInstalledChromeLabel(title)
            || text === installedLabel || aria === installedLabel;
          if (looksRemove) {
            targetLabel = removeLabel;
          } else if (looksInstall || looksInstalled) {
            targetLabel = (pageInstalled || looksInstalled) ? installedLabel : addLabel;
          }
          if (!targetLabel) continue;
          if (aria && (looksRemove || isInstallChromeLabel(aria) || isInstalledChromeLabel(aria) || isRemoveChromeLabel(aria))) {
            el.setAttribute('aria-label', targetLabel);
          }
          if (title && (looksRemove || isInstallChromeLabel(title) || isInstalledChromeLabel(title) || isRemoveChromeLabel(title))) {
            el.setAttribute('title', targetLabel);
          }
          rewriteTextNodeOrLeaf(el, targetLabel);
        }
      }

      function isPhoneIncompatText(text) {
        var api = i18n();
        if (api) return api.isPhoneIncompatText(text);
        return /not compatible with|Item currently unavailable|only (works|available|installable) on (a )?(desktop|computer)|alleen (beschikbaar|te installeren) op/i.test(text || '');
      }

      function hideUnavailable() {
        if (!document.body) return;
        var candidates = document.querySelectorAll('div, section, span, p, h1, h2, h3, li, button, a');
        for (var i = 0; i < candidates.length; i++) {
          var el = candidates[i];
          if (el.getAttribute('data-oriel-hidden-unavailable') === '1') continue;
          if (el.id === 'oriel-add-to-oriel' || el.id === 'oriel-install-bar' || el.id === 'oriel-cws-tip') continue;
          if (el.closest && el.closest('#oriel-install-bar')) continue;
          if (el.childElementCount > 12) continue;
          var text = normalizeLabel(el.textContent);
          if (text.length < 10 || text.length > 320) continue;
          if (!isPhoneIncompatText(text)) continue;
          var target = el;
          // Prefer hiding a small banner wrapper, not the whole page.
          var parent = el.parentElement;
          if (parent && parent !== document.body && parent.childElementCount <= 4) {
            var pText = normalizeLabel(parent.textContent);
            if (pText.length <= 360 && isPhoneIncompatText(pText)) target = parent;
          }
          target.style.setProperty('display', 'none', 'important');
          target.setAttribute('data-oriel-hidden-unavailable', '1');
        }
      }

      /** Sticky phone-width install bar — CWS often hides native install on mobile layouts. */
      function ensureInstallBar() {
        var id = idFromPath();
        var bar = document.getElementById('oriel-install-bar');
        if (!id) {
          if (bar) bar.remove();
          document.documentElement.style.removeProperty('padding-bottom');
          return;
        }
        if (!document.body) return;
        if (!bar) {
          bar = document.createElement('div');
          bar.id = 'oriel-install-bar';
          bar.setAttribute('role', 'region');
          bar.setAttribute('aria-label', 'Oriel');
          bar.style.cssText = [
            'position:fixed', 'left:0', 'right:0', 'bottom:0', 'z-index:2147483646',
            'padding:12px 16px calc(12px + env(safe-area-inset-bottom, 0px))',
            'background:rgba(255,255,255,0.96)', 'backdrop-filter:blur(12px)',
            '-webkit-backdrop-filter:blur(12px)',
            'border-top:1px solid rgba(0,0,0,0.08)',
            'box-shadow:0 -4px 24px rgba(0,0,0,0.08)',
            'font-family:-apple-system,BlinkMacSystemFont,system-ui,sans-serif'
          ].join(';');
          var tip = document.createElement('p');
          tip.id = 'oriel-cws-tip';
          tip.style.cssText = 'margin:0 0 8px;font-size:13px;line-height:1.35;color:#444;text-align:center';
          tip.textContent = L('tipChrome');
          var btn = document.createElement('button');
          btn.id = 'oriel-add-to-oriel';
          btn.type = 'button';
          btn.style.cssText = [
            'display:block', 'width:100%', 'min-height:48px', 'border:0', 'border-radius:12px',
            'background:#1a73e8', 'color:#fff', 'font-size:16px', 'font-weight:600',
            'padding:12px 16px', '-webkit-tap-highlight-color:transparent'
          ].join(';');
          btn.addEventListener('click', function (event) {
            event.preventDefault();
            event.stopPropagation();
            if (event.stopImmediatePropagation) event.stopImmediatePropagation();
            var extId = idFromPath();
            if (!extId) return;
            if (isInstalled(extId)) openManage();
            else postInstall(extId);
          });
          bar.appendChild(tip);
          bar.appendChild(btn);
          document.body.appendChild(bar);
        }
        var tipEl = document.getElementById('oriel-cws-tip');
        if (tipEl) tipEl.textContent = L('tipChrome');
        var btnEl = document.getElementById('oriel-add-to-oriel');
        if (btnEl) {
          var label = isInstalled(id) ? L('installed') : L('add');
          btnEl.textContent = label;
          btnEl.setAttribute('aria-label', label);
          btnEl.style.background = isInstalled(id) ? '#5f6368' : '#1a73e8';
        }
        document.documentElement.style.setProperty(
          'padding-bottom',
          'calc(108px + env(safe-area-inset-bottom, 0px))',
          'important'
        );
      }

      function onClick(event) {
        var t = event.target;
        if (!t || !t.closest) return;
        if (t.closest('#oriel-install-bar')) return; // handled by button listener
        var el = t.closest('button, a, div[role="button"], span[role="button"]');
        if (!el) return;
        var label = normalizeLabel(el.textContent);
        var aria = normalizeLabel(el.getAttribute('aria-label'));
        var title = normalizeLabel(el.getAttribute('title'));
        var addLabel = L('add');
        var installedLabel = L('installed');
        var removeLabel = L('remove');
        var looksRemove = isRemoveChromeLabel(label) || isRemoveChromeLabel(aria) || isRemoveChromeLabel(title)
          || label === removeLabel || aria === removeLabel;
        var isOriel = label === addLabel || label === installedLabel || label === removeLabel
          || aria === addLabel || aria === removeLabel || /oriel/i.test(label) || /oriel/i.test(aria);
        var isChromeCTA = isInstallChromeLabel(label) || isInstallChromeLabel(aria) || isInstallChromeLabel(title);
        if (!isOriel && !isChromeCTA && !looksRemove) return;
        if (Math.max(label.length, aria.length) > 72) return;
        var id = idFromPath();
        if (!id) return;
        event.preventDefault();
        event.stopPropagation();
        if (event.stopImmediatePropagation) event.stopImmediatePropagation();
        if (looksRemove || isInstalled(id)) openManage();
        else postInstall(id);
      }

      function refresh() {
        if (busy || !document.body) return;
        busy = true;
        try {
          rewriteLabels();
          if (idFromPath()) hideUnavailable();
          ensureInstallBar();
        } finally { busy = false; }
      }
      function schedule() {
        if (scheduled != null) return;
        scheduled = setTimeout(function () { scheduled = null; refresh(); }, 300);
      }

      document.addEventListener('click', onClick, true);
      window.addEventListener('oriel-installed-changed', function () { schedule(); });
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
