import Foundation

enum FirefoxAddonsAPI {
    static let installURLScheme = "oriel-firefox-addon"

    /// Slug from `https://addons.mozilla.org/.../firefox/addon/<slug>/`
    static func slug(fromStoreURL url: URL) -> String? {
        let parts = url.path.split(separator: "/").map(String.init)
        guard let addonIndex = parts.firstIndex(of: "addon"),
              addonIndex + 1 < parts.count else { return nil }
        let slug = parts[addonIndex + 1]
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !slug.isEmpty, slug != "null" else { return nil }
        return slug
    }

    static func slug(fromInstallURL url: URL) -> String? {
        guard url.scheme?.lowercased() == installURLScheme else { return nil }
        if url.host?.lowercased() == "manage" { return nil }
        if let host = url.host, !host.isEmpty, host.lowercased() != "install" {
            return host
        }
        let parts = url.path.split(separator: "/").map(String.init)
        return parts.last(where: { !$0.isEmpty && $0.lowercased() != "install" })
    }

    static func isManageExtensionsURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == installURLScheme else { return false }
        return url.host?.lowercased() == "manage"
    }

    static func installURL(forSlug slug: String) -> URL? {
        let trimmed = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: "\(installURLScheme)://install/\(trimmed)")
    }

    /// AMO API v5 addon detail → current signed XPI URL.
    static func detailURL(forSlugOrID slugOrID: String) -> URL? {
        let encoded = slugOrID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slugOrID
        return URL(string: "https://addons.mozilla.org/api/v5/addons/addon/\(encoded)/")
    }

    static func xpiURL(fromDetailJSON data: Data) -> URL? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let current = root["current_version"] as? [String: Any] {
            if let file = current["file"] as? [String: Any],
               let urlString = file["url"] as? String,
               let url = URL(string: urlString) {
                return url
            }
            // Older AMO payloads used `files: [{url}]`.
            if let files = current["files"] as? [[String: Any]],
               let urlString = files.first?["url"] as? String,
               let url = URL(string: urlString) {
                return url
            }
        }
        return nil
    }

    static func displayName(fromDetailJSON data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = root["name"] as? [String: Any] else { return nil }
        return (name["en-US"] as? String) ?? (name.values.first as? String)
    }
}

/// Injected into addons.mozilla.org so “Add to Firefox” becomes installable in Oriel.
enum FirefoxAddonsBridge {
    static let handlerName = "orielInstallFirefoxAddon"

    /// Document-start: look like desktop Firefox so AMO enables install UI on iPhone/iPad.
    static let desktopSpoofSource = #"""
    (function () {
      if (window.__orielFirefoxDesktopSpoof) return;
      window.__orielFirefoxDesktopSpoof = true;
      var h = location.hostname;
      if (h !== 'addons.mozilla.org' && h !== 'addons-dev.allizom.org' && !h.endsWith('.addons.mozilla.org')) return;

      var desktopUA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:133.0) Gecko/20100101 Firefox/133.0';
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
        Object.defineProperty(navigator, 'vendor', { configurable: true, get: function () { return ''; } });
      } catch (e) {}
      try {
        Object.defineProperty(navigator, 'maxTouchPoints', { configurable: true, get: function () { return 0; } });
      } catch (e) {}
      // Legacy AMO / old install buttons check InstallTrigger.
      try {
        if (typeof window.InstallTrigger === 'undefined') {
          window.InstallTrigger = { enabled: function () { return true; } };
        }
      } catch (e) {}
    })();
    """#

    static let userScriptSource = #"""
    (function () {
      if (window.__orielFirefoxAddonsBridge) return;
      window.__orielFirefoxAddonsBridge = true;
      var h = location.hostname;
      if (h !== 'addons.mozilla.org' && h !== 'addons-dev.allizom.org' && !h.endsWith('.addons.mozilla.org')) return;

      function slugFromPath() {
        var parts = location.pathname.split('/').filter(Boolean);
        var idx = parts.indexOf('addon');
        if (idx >= 0 && parts[idx + 1]) return parts[idx + 1];
        return null;
      }

      function postInstall(slug) {
        if (!slug) return;
        try {
          if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.orielInstallFirefoxAddon) {
            window.webkit.messageHandlers.orielInstallFirefoxAddon.postMessage(String(slug));
            return;
          }
        } catch (e) {}
        try {
          var a = document.createElement('a');
          a.href = 'oriel-firefox-addon://install/' + encodeURIComponent(slug);
          a.rel = 'noreferrer';
          a.style.display = 'none';
          document.documentElement.appendChild(a);
          a.click();
          a.remove();
        } catch (e2) {}
      }
      window.__orielPostFirefoxInstall = postInstall;

      function isDownloadFirefoxBanner(text) {
        if (!text) return false;
        if (/you.?ll need firefox/i.test(text)) return true;
        if (/need to download firefox/i.test(text)) return true;
        if (/download firefox (and|to) (get|use|install)/i.test(text)) return true;
        if (/to use (these|this) add-?ons?, you.?ll need/i.test(text)) return true;
        if (/only available (for|on) (desktop )?firefox/i.test(text)) return true;
        if (/not available (on|for) (your )?(phone|mobile|ios|iphone|ipad|android)/i.test(text)) return true;
        if (/available for firefox for android/i.test(text) && /not (available|supported).{0,40}ios/i.test(text)) return true;
        return false;
      }

      function hideBanners() {
        if (!document.body) return;
        var candidates = document.querySelectorAll('div, section, span, p, h1, h2, h3, aside, li');
        for (var i = 0; i < candidates.length; i++) {
          var el = candidates[i];
          if (el.getAttribute('data-oriel-hidden-amo') === '1') continue;
          if (el.id === 'oriel-add-firefox-to-oriel' || el.id === 'oriel-amo-tip') continue;
          if (el.childElementCount > 8) continue;
          var text = (el.textContent || '').replace(/\s+/g, ' ').trim();
          if (text.length < 12 || text.length > 240) continue;
          if (!isDownloadFirefoxBanner(text)) continue;
          el.style.setProperty('display', 'none', 'important');
          el.setAttribute('data-oriel-hidden-amo', '1');
        }
      }

      function ensureTip() {
        var slug = slugFromPath();
        var tip = document.getElementById('oriel-amo-tip');
        if (!slug) { if (tip) tip.remove(); return; }
        if (!tip) {
          tip = document.createElement('div');
          tip.id = 'oriel-amo-tip';
          tip.setAttribute('role', 'status');
          Object.assign(tip.style, {
            position: 'fixed', left: '12px', right: '12px', bottom: '72px', zIndex: '2147483645',
            padding: '10px 14px', borderRadius: '10px',
            background: 'rgba(255, 113, 57, 0.95)', color: '#fff',
            font: '600 13px/1.35 -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif',
            boxShadow: '0 6px 20px rgba(0,0,0,0.18)', textAlign: 'center',
            pointerEvents: 'none'
          });
          tip.textContent = 'Oriel can install this Firefox add-on on iPhone and iPad — tap Add to Oriel.';
          (document.body || document.documentElement).appendChild(tip);
        }
      }

      function ensureButton() {
        var slug = slugFromPath();
        var btn = document.getElementById('oriel-add-firefox-to-oriel');
        if (!slug) { if (btn) btn.remove(); return; }
        if (!btn) {
          btn = document.createElement('button');
          btn.id = 'oriel-add-firefox-to-oriel';
          btn.type = 'button';
          Object.assign(btn.style, {
            position: 'fixed', right: '20px', bottom: '20px', zIndex: '2147483646',
            padding: '12px 18px', border: '0', borderRadius: '10px',
            background: '#ff7139', color: '#fff', cursor: 'pointer',
            font: '600 14px -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif',
            boxShadow: '0 6px 20px rgba(0,0,0,0.22)'
          });
          btn.addEventListener('click', function (event) {
            event.preventDefault();
            event.stopPropagation();
            var current = slugFromPath();
            if (!current) return;
            btn.disabled = true;
            btn.textContent = 'Installing…';
            postInstall(current);
            setTimeout(function () {
              btn.disabled = false;
              btn.textContent = 'Add to Oriel';
            }, 4500);
          }, true);
          (document.body || document.documentElement).appendChild(btn);
        }
        btn.textContent = 'Add to Oriel';
      }

      function relabel() {
        var slug = slugFromPath();
        if (!slug) return;
        var buttons = document.querySelectorAll(
          'button, a, .InstallButtonWrapper a, .AMInstallButton-button, [class*="InstallButton"]'
        );
        buttons.forEach(function (el) {
          var text = (el.textContent || '').trim();
          if (!/add to firefox|download file|install theme|add theme|download firefox/i.test(text)) return;
          if (el.dataset.orielFirefoxBound === '1') return;
          el.dataset.orielFirefoxBound = '1';
          try {
            if (/download firefox/i.test(text)) {
              el.textContent = 'Add to Oriel';
            } else {
              el.textContent = /theme/i.test(text) ? 'Add theme to Oriel' : 'Add to Oriel';
            }
          } catch (e) {}
          el.addEventListener('click', function (ev) {
            ev.preventDefault();
            ev.stopPropagation();
            postInstall(slug);
          }, true);
        });
      }

      var busy = false;
      var scheduled = null;
      function refresh() {
        if (busy || !document.body) return;
        busy = true;
        try {
          relabel();
          if (slugFromPath()) { hideBanners(); ensureTip(); ensureButton(); }
          else {
            var btn = document.getElementById('oriel-add-firefox-to-oriel');
            if (btn) btn.remove();
            var tip = document.getElementById('oriel-amo-tip');
            if (tip) tip.remove();
          }
        } finally { busy = false; }
      }
      function schedule() {
        if (scheduled != null) return;
        scheduled = setTimeout(function () { scheduled = null; refresh(); }, 300);
      }

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
