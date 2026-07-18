import Foundation

/// Lightweight page cleanup inspired by Safari advanced-blocking approaches (wBlock / AdGuard):
/// removes leftover ad iframes and sticky ad shells that slip past `WKContentRuleList`.
enum AdvancedPageCleanupScript {
    static let source = #"""
    (function () {
      if (window.__orielPageCleanup) return;
      window.__orielPageCleanup = true;
      window.__orielPageCleanupKill = false;

      var AD_HOST = /(doubleclick\.net|googlesyndication\.com|googleadservices\.com|adnxs\.com|adsrvr\.org|amazon-adsystem\.com|outbrain\.com|taboola\.com|criteo\.(com|net)|pubmatic\.com|rubiconproject\.com|openx\.net|casalemedia\.com|moatads\.com|teads\.tv|mgid\.com|revcontent\.com|scorecardresearch\.com|quantserve\.com|popads\.net|exoclick\.com|juicyads\.com|propellerads\.com|media\.net|3lift\.com|bidswitch\.net)/i;

      var KILL_SEL = [
        'iframe[id*="google_ads" i]',
        'iframe[src*="doubleclick" i]',
        'iframe[src*="googlesyndication" i]',
        'iframe[src*="adnxs" i]',
        'iframe[src*="outbrain" i]',
        'iframe[src*="taboola" i]',
        'ins.adsbygoogle',
        'div[id^="div-gpt-ad"]',
        'div[id^="google_ads_"]',
        'div[class*="adsbygoogle" i]',
        '[data-ad-slot]',
        '[data-google-query-id]',
        '.taboola-wrapper',
        '.OUTBRAIN',
        '#taboola-below-article-thumbnails',
        'div[id*="taboola" i]',
        'div[class*="taboola" i]',
        'div[id*="outbrain" i]',
        'aside[class*="advert" i]',
        'div[aria-label*="advertisement" i]',
        'div[aria-label*="Advertisement" i]'
      ].join(',');

      function hostOK() {
        var h = (location.hostname || '').toLowerCase();
        if (!h) return false;
        // Never run destructive cleanup on auth / payment / bank-ish hosts.
        if (/(^|\.)(accounts\.google|appleid\.apple|login\.live|paypal|stripe|bank|github)\./.test(h)) return false;
        return true;
      }

      function nuke() {
        if (window.__orielPageCleanupKill || !hostOK()) return;
        var nodes = document.querySelectorAll(KILL_SEL);
        for (var i = 0; i < nodes.length; i++) {
          try { nodes[i].remove(); } catch (e) {}
        }
        var iframes = document.querySelectorAll('iframe[src]');
        for (var j = 0; j < iframes.length; j++) {
          var src = iframes[j].getAttribute('src') || '';
          if (AD_HOST.test(src)) {
            try { iframes[j].remove(); } catch (e) {}
          }
        }
        // Sticky / fixed high-z overlays that look like ad units (narrow heuristic).
        var all = document.querySelectorAll('div,aside,section');
        for (var k = 0; k < all.length && k < 400; k++) {
          var el = all[k];
          var idc = ((el.id || '') + ' ' + (el.className || '')).toLowerCase();
          if (!/(^|[\s_-])(ad|ads|advert|sponsor|promo)([\s_-]|$)/.test(idc)) continue;
          if (/(header|nav|main|article|content|footer|logo|search|menu|cookie|consent)/.test(idc)) continue;
          try {
            var st = window.getComputedStyle(el);
            if (!st) continue;
            var pos = st.position;
            var z = parseInt(st.zIndex, 10) || 0;
            if ((pos === 'fixed' || pos === 'sticky') && z >= 1000) {
              var r = el.getBoundingClientRect();
              if (r.width > 120 && r.height > 40 && r.height < 420) el.remove();
            }
          } catch (e) {}
        }
      }

      nuke();
      setInterval(nuke, 1500);
      document.addEventListener('DOMContentLoaded', nuke, true);
    })();
    """#

    static let disableSource = "window.__orielPageCleanupKill = true;"
}
