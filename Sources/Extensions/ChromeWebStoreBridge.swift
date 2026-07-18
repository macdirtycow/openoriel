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

    /// `oriel-extension://install/<id>` or `oriel-extension:<id>`
    static func extensionID(fromInstallURL url: URL) -> String? {
        guard url.scheme?.lowercased() == installURLScheme else { return nil }
        if url.host?.lowercased() == "manage" { return nil }
        if let host = url.host?.lowercased(), isValidExtensionID(host) {
            return host
        }
        let parts = url.path.split(separator: "/").map { $0.lowercased() }
        if let id = parts.last(where: isValidExtensionID) {
            return id
        }
        if let id = url.absoluteString
            .split(separator: ":")
            .last?
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased(),
           isValidExtensionID(id) {
            return id
        }
        return nil
    }

    static func isManageExtensionsURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == installURLScheme else { return false }
        if url.host?.lowercased() == "manage" { return true }
        return url.path.lowercased().contains("manage")
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

    /// Shared helpers used by both content worlds.
    private static let sharedHelpers = #"""
      function orielValidId(id) {
        return typeof id === 'string' && /^[a-p]{32}$/.test(id);
      }
      function orielIdFromPath() {
        var parts = location.pathname.split('/').filter(Boolean);
        for (var i = parts.length - 1; i >= 0; i--) {
          if (orielValidId(parts[i])) return parts[i];
        }
        return null;
      }
      function orielPostInstall(id) {
        if (!orielValidId(id)) return false;
        var ok = false;
        try {
          if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.orielInstallExtension) {
            window.webkit.messageHandlers.orielInstallExtension.postMessage(String(id));
            ok = true;
          }
        } catch (e) {}
        // Always also poke the native navigation bridge — messageHandlers can be missing
        // depending on WKContentWorld, and empty failures look like “Add to Oriel does nothing”.
        try {
          var iframe = document.createElement('iframe');
          iframe.style.cssText = 'display:none!important;width:0;height:0;border:0;position:absolute';
          iframe.src = 'oriel-extension://install/' + id;
          document.documentElement.appendChild(iframe);
          setTimeout(function () { try { iframe.remove(); } catch (e) {} }, 1500);
          ok = true;
        } catch (e) {}
        return ok;
      }
    """#

    /// Runs at document start in the page world so the store’s own scripts see Chrome APIs.
    static var chromeAPIStubSource: String {
        #"""
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

        """# + sharedHelpers + #"""

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
              var installed = window.__orielInstalledExtensionIDs || [];
              if (id && installed.indexOf(String(id).toLowerCase()) !== -1) {
                if (typeof cb === 'function') cb('enabled');
                return;
              }
              if (typeof cb === 'function') cb('installable');
            },
            beginInstallWithManifest3: function (extinfo, cb) {
              var id = null;
              if (typeof extinfo === 'string') id = extinfo;
              else if (extinfo && typeof extinfo.id === 'string') id = extinfo.id;
              if (!id) id = orielIdFromPath();
              var installed = window.__orielInstalledExtensionIDs || [];
              if (id && installed.indexOf(String(id).toLowerCase()) !== -1) {
                try {
                  var iframe = document.createElement('iframe');
                  iframe.style.cssText = 'display:none!important;width:0;height:0;border:0;position:absolute';
                  iframe.src = 'oriel-extension://manage';
                  document.documentElement.appendChild(iframe);
                  setTimeout(function () { try { iframe.remove(); } catch (e) {} }, 1500);
                } catch (e) {}
              } else {
                orielPostInstall(id);
              }
              if (typeof cb === 'function') cb('user_cancelled');
            },
            isInIncognitoMode: function (cb) { if (typeof cb === 'function') cb(false); },
            getReferrerChain: function (cb) { if (typeof cb === 'function') cb('EgIIAA=='); },
            completeInstall: function (id, cb) { if (typeof cb === 'function') cb(true); }
          };

          chromeObj.management = chromeObj.management || {
            getAll: function (cb) {
              var installed = window.__orielInstalledExtensionIDs || [];
              var items = installed.map(function (extId) {
                return { id: extId, name: extId, enabled: true, type: 'extension', installType: 'normal' };
              });
              if (typeof cb === 'function') cb(items);
            },
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
    }

    /// DOM UI bridge — runs in the default client world where messageHandlers are reliable.
    static var userScriptSource: String {
        #"""
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

        """# + sharedHelpers + #"""

          var scheduled = null;
          var busy = false;

          function controlLabel(el) {
            if (!el) return '';
            return (el.textContent || '').replace(/\s+/g, ' ').trim();
          }

          function looksLikeInstallControl(el) {
            if (!el || el.id === 'oriel-add-to-oriel') return false;
            return /Add to (Chrome|Brave|Oriel)/i.test(controlLabel(el));
          }

          function hideUnavailableBanners() {
            if (!document.body) return;
            var candidates = document.querySelectorAll('div, section, span, p');
            for (var i = 0; i < candidates.length; i++) {
              var el = candidates[i];
              if (el.getAttribute('data-oriel-hidden-unavailable') === '1') continue;
              if (el.childElementCount > 8) continue;
              var text = (el.textContent || '').replace(/\s+/g, ' ').trim();
              if (text.length < 20 || text.length > 220) continue;
              if (!/Item currently unavailable/i.test(text)) continue;
              el.style.setProperty('display', 'none', 'important');
              el.setAttribute('data-oriel-hidden-unavailable', '1');
            }
          }

          function rewriteInstallLabels() {
            var nodes = document.querySelectorAll('button, a, div[role="button"], span[role="button"]');
            for (var i = 0; i < nodes.length; i++) {
              var el = nodes[i];
              if (!looksLikeInstallControl(el)) continue;
              if (el.childElementCount === 0) {
                if (/Add to (Chrome|Brave)/i.test(controlLabel(el))) {
                  el.textContent = 'Add to Oriel';
                }
                continue;
              }
              var spans = el.querySelectorAll('span');
              for (var s = 0; s < spans.length; s++) {
                var span = spans[s];
                if (span.childElementCount === 0 && /Add to (Chrome|Brave)/i.test((span.textContent || '').trim())) {
                  span.textContent = 'Add to Oriel';
                }
              }
              el.setAttribute('aria-label', 'Add to Oriel');
            }
          }

          function replaceStoreInstallButton() {
            var id = orielIdFromPath();
            if (!id || !document.body) return;
            var installed = (window.__orielInstalledExtensionIDs || []).indexOf(id) !== -1;

            var existing = document.getElementById('oriel-store-install-btn');
            if (existing) {
              existing.textContent = installed ? 'Installed in Oriel' : 'Add to Oriel';
              existing.dataset.orielInstalled = installed ? '1' : '0';
              return;
            }

            var nodes = document.querySelectorAll('button, div[role="button"]');
            var target = null;
            for (var i = 0; i < nodes.length; i++) {
              if (looksLikeInstallControl(nodes[i])) {
                target = nodes[i];
                break;
              }
            }
            if (!target || target.dataset.orielReplaced === '1') return;

            var replacement = document.createElement('button');
            replacement.type = 'button';
            replacement.id = 'oriel-store-install-btn';
            replacement.textContent = installed ? 'Installed in Oriel' : 'Add to Oriel';
            replacement.setAttribute('aria-label', replacement.textContent);
            replacement.dataset.orielReplaced = '1';
            replacement.dataset.orielInstalled = installed ? '1' : '0';
            Object.assign(replacement.style, {
              appearance: 'none',
              border: '0',
              borderRadius: '24px',
              padding: '10px 22px',
              background: installed ? '#5f6368' : '#1a73e8',
              color: '#fff',
              font: '600 14px / 20px Google Sans, Roboto, Helvetica, Arial, sans-serif',
              cursor: 'pointer',
              minWidth: '140px'
            });
            replacement.addEventListener('click', function (event) {
              event.preventDefault();
              event.stopPropagation();
              if (typeof event.stopImmediatePropagation === 'function') event.stopImmediatePropagation();
              var current = orielIdFromPath();
              if (!current) return;
              var isInstalled = (window.__orielInstalledExtensionIDs || []).indexOf(current) !== -1;
              if (isInstalled) {
                try {
                  var iframe = document.createElement('iframe');
                  iframe.style.cssText = 'display:none!important;width:0;height:0;border:0;position:absolute';
                  iframe.src = 'oriel-extension://manage';
                  document.documentElement.appendChild(iframe);
                  setTimeout(function () { try { iframe.remove(); } catch (e) {} }, 1500);
                } catch (e) {}
                return;
              }
              replacement.disabled = true;
              replacement.textContent = 'Installing…';
              orielPostInstall(current);
              setTimeout(function () {
                replacement.disabled = false;
                replacement.textContent = 'Add to Oriel';
              }, 4000);
            }, true);

            target.dataset.orielReplaced = '1';
            target.replaceWith(replacement);
          }

          function ensureFloatingButton() {
            var id = orielIdFromPath();
            var btn = document.getElementById('oriel-add-to-oriel');
            if (!id) {
              if (btn) btn.remove();
              return;
            }
            var installed = (window.__orielInstalledExtensionIDs || []).indexOf(id) !== -1;
            if (!btn) {
              btn = document.createElement('button');
              btn.id = 'oriel-add-to-oriel';
              btn.type = 'button';
              Object.assign(btn.style, {
                position: 'fixed',
                right: '20px',
                bottom: '20px',
                zIndex: '2147483646',
                padding: '12px 18px',
                border: '0',
                borderRadius: '10px',
                color: '#ffffff',
                font: '600 14px -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif',
                cursor: 'pointer',
                boxShadow: '0 6px 20px rgba(0,0,0,0.22)'
              });
              btn.addEventListener('click', function (event) {
                event.preventDefault();
                event.stopPropagation();
                var current = orielIdFromPath();
                if (!current) return;
                var isInstalled = (window.__orielInstalledExtensionIDs || []).indexOf(current) !== -1;
                if (isInstalled) {
                  try {
                    var iframe = document.createElement('iframe');
                    iframe.style.cssText = 'display:none!important;width:0;height:0;border:0;position:absolute';
                    iframe.src = 'oriel-extension://manage';
                    document.documentElement.appendChild(iframe);
                    setTimeout(function () { try { iframe.remove(); } catch (e) {} }, 1500);
                  } catch (e) {}
                  return;
                }
                btn.disabled = true;
                btn.textContent = 'Installing…';
                orielPostInstall(current);
                setTimeout(function () {
                  btn.disabled = false;
                  var stillInstalled = (window.__orielInstalledExtensionIDs || []).indexOf(current) !== -1;
                  btn.textContent = stillInstalled ? 'Installed in Oriel' : 'Add to Oriel';
                  btn.style.background = stillInstalled ? '#5f6368' : '#1a73e8';
                }, 4000);
              }, true);
              (document.body || document.documentElement).appendChild(btn);
            }
            btn.textContent = installed ? 'Installed in Oriel' : 'Add to Oriel';
            btn.style.background = installed ? '#5f6368' : '#1a73e8';
            btn.setAttribute('aria-label', btn.textContent);
          }

          function installClickCapture(event) {
            var target = event.target;
            if (!target || !target.closest) return;
            var el = target.closest('button, a, div[role="button"], span[role="button"]');
            if (!el) return;
            if (el.id === 'oriel-add-to-oriel' || el.id === 'oriel-store-install-btn') return;
            if (!looksLikeInstallControl(el)) return;
            var id = orielIdFromPath();
            if (!id) return;
            event.preventDefault();
            event.stopPropagation();
            if (typeof event.stopImmediatePropagation === 'function') event.stopImmediatePropagation();
            orielPostInstall(id);
          }

          function refresh() {
            if (busy || !document.body) return;
            busy = true;
            try {
              rewriteInstallLabels();
              if (orielIdFromPath()) {
                hideUnavailableBanners();
                replaceStoreInstallButton();
                ensureFloatingButton();
              } else {
                var btn = document.getElementById('oriel-add-to-oriel');
                if (btn) btn.remove();
              }
            } finally {
              busy = false;
            }
          }

          function scheduleRefresh() {
            if (scheduled != null) return;
            scheduled = setTimeout(function () {
              scheduled = null;
              refresh();
            }, 250);
          }

          document.addEventListener('click', installClickCapture, true);
          refresh();

          var obs = new MutationObserver(function () {
            if (busy) return;
            scheduleRefresh();
          });
          obs.observe(document.documentElement, { childList: true, subtree: true });

          window.addEventListener('popstate', scheduleRefresh);
          var pathProbe = location.pathname;
          setInterval(function () {
            if (location.pathname !== pathProbe) {
              pathProbe = location.pathname;
              scheduleRefresh();
            }
          }, 1000);
        })();
        """#
    }
}
