import Foundation

enum PageEnhancementScripts {
    /// Overlay reader that preserves the original page for a clean exit.
    static let readerMode = #"""
    (function() {
      var existing = document.getElementById('oriel-reader-overlay');
      if (existing) {
        existing.remove();
        document.documentElement.style.overflow = '';
        return 'off';
      }

      function scoreNode(el) {
        if (!el || !el.tagName) return 0;
        var tag = el.tagName.toLowerCase();
        if (['script','style','nav','footer','header','aside','form','iframe','noscript','svg'].indexOf(tag) >= 0) return -1e9;
        var text = (el.innerText || '').replace(/\s+/g, ' ').trim();
        var len = text.length;
        if (len < 80) return 0;
        var score = len;
        var cls = ((el.className || '') + ' ' + (el.id || '')).toLowerCase();
        if (/article|content|post|entry|story|main/.test(cls) || tag === 'article' || tag === 'main') score *= 1.6;
        if (/comment|sidebar|related|promo|footer|header|nav|menu|share/.test(cls)) score *= 0.25;
        var ps = el.querySelectorAll('p').length;
        score += ps * 40;
        return score;
      }

      var candidates = Array.prototype.slice.call(document.querySelectorAll('article, main, [role="main"], .post, .article, .content, #content, #main'));
      if (!candidates.length) candidates = Array.prototype.slice.call(document.body.querySelectorAll('div, section'));
      var best = null, bestScore = 0;
      candidates.forEach(function(el) {
        var s = scoreNode(el);
        if (s > bestScore) { bestScore = s; best = el; }
      });
      if (!best || bestScore < 120) best = document.querySelector('article') || document.querySelector('main') || document.body;

      var clone = best.cloneNode(true);
      clone.querySelectorAll('script, style, nav, footer, header, iframe, noscript, svg, form, button, .share, .social, [aria-hidden="true"]').forEach(function(n){ n.remove(); });
      var text = (clone.innerText || clone.textContent || '').trim();
      if (text.length < 80) return 'too-short';

      var title = document.title || '';
      var h1 = document.querySelector('h1');
      if (h1 && h1.innerText.trim().length > 3) title = h1.innerText.trim();

      function esc(s) {
        return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
      }

      var overlay = document.createElement('div');
      overlay.id = 'oriel-reader-overlay';
      overlay.setAttribute('role', 'dialog');
      overlay.innerHTML = ''
        + '<style>'
        + '#oriel-reader-overlay{position:fixed;inset:0;z-index:2147483646;overflow:auto;background:#f4f1ea;color:#1c1b19;'
        + 'font:21px/1.65 -apple-system,BlinkMacSystemFont,"Segoe UI",Georgia,serif;}'
        + '@media(prefers-color-scheme:dark){#oriel-reader-overlay{background:#141311;color:#f2efe8;}}'
        + '#oriel-reader-overlay .oriel-reader-inner{max-width:42rem;margin:0 auto;padding:max(24px,6vh) 6vw 12vh;}'
        + '#oriel-reader-overlay h1{font-size:1.85rem;line-height:1.25;margin:0 0 1.25rem;font-weight:700;}'
        + '#oriel-reader-overlay p,#oriel-reader-overlay li{margin:0 0 1rem;}'
        + '#oriel-reader-overlay img,#oriel-reader-overlay video{max-width:100%;height:auto;border-radius:10px;}'
        + '#oriel-reader-overlay a{color:#0b6bcb;}'
        + '#oriel-reader-overlay.oriel-reader-lg{font-size:24px;}'
        + '#oriel-reader-overlay.oriel-reader-sm{font-size:18px;}'
        + '</style>'
        + '<div class="oriel-reader-inner"><h1>' + esc(title) + '</h1>' + clone.innerHTML + '</div>';

      document.documentElement.style.overflow = 'hidden';
      document.documentElement.appendChild(overlay);
      overlay.scrollTop = 0;
      return 'on';
    })();
    """#

    static func readerFontSize(_ size: String) -> String {
        // size: sm | md | lg
        """
        (function() {
          var o = document.getElementById('oriel-reader-overlay');
          if (!o) return false;
          o.classList.remove('oriel-reader-sm','oriel-reader-lg');
          if ('\(size)' === 'sm') o.classList.add('oriel-reader-sm');
          if ('\(size)' === 'lg') o.classList.add('oriel-reader-lg');
          return true;
        })();
        """
    }

    static let enableForceDark = #"""
    (function() {
      var s = document.getElementById('oriel-force-dark');
      if (!s) {
        s = document.createElement('style');
        s.id = 'oriel-force-dark';
        s.textContent = 'html{filter:invert(1) hue-rotate(180deg);} img,video,picture,svg{filter:invert(1) hue-rotate(180deg);}';
        (document.head || document.documentElement).appendChild(s);
      }
      return true;
    })();
    """#

    static let disableForceDark = #"""
    (function() {
      var s = document.getElementById('oriel-force-dark');
      if (s) s.remove();
      return true;
    })();
    """#

    static let enableFocusMode = #"""
    (function() {
      function hush(el) {
        try {
          el.muted = true;
          el.autoplay = false;
          if (!el.paused) el.pause();
          el.removeAttribute('autoplay');
        } catch (e) {}
      }
      document.querySelectorAll('video, audio').forEach(hush);
      if (!window.__orielFocusObserver) {
        window.__orielFocusObserver = new MutationObserver(function(muts) {
          muts.forEach(function(m) {
            m.addedNodes.forEach(function(n) {
              if (n.querySelectorAll) {
                n.querySelectorAll('video, audio').forEach(hush);
              }
              if (n.tagName === 'VIDEO' || n.tagName === 'AUDIO') hush(n);
            });
          });
        });
        window.__orielFocusObserver.observe(document.documentElement, { childList: true, subtree: true });
      }
      var s = document.getElementById('oriel-focus-mode');
      if (!s) {
        s = document.createElement('style');
        s.id = 'oriel-focus-mode';
        s.textContent = '[class*="cookie"],[id*="cookie"],[class*="consent"],[id*="consent"],[class*="newsletter"],[id*="newsletter"],[class*="promo-banner"],[id*="promo"]{display:none!important;}';
        (document.head || document.documentElement).appendChild(s);
      }
      return true;
    })();
    """#

    static let disableFocusMode = #"""
    (function() {
      if (window.__orielFocusObserver) {
        try { window.__orielFocusObserver.disconnect(); } catch (e) {}
        window.__orielFocusObserver = null;
      }
      var s = document.getElementById('oriel-focus-mode');
      if (s) s.remove();
      return true;
    })();
    """#

    static func setZoom(_ factor: Double) -> String {
        let clamped = min(3.0, max(0.5, factor))
        return "document.documentElement.style.zoom = '\(clamped)';"
    }

    /// GX-style Lucid Mode — sharpen / contrast boost for images and video (CSS only).
    static let enableLucidMode = #"""
    (function() {
      var s = document.getElementById('oriel-lucid-mode');
      if (!s) {
        s = document.createElement('style');
        s.id = 'oriel-lucid-mode';
        s.textContent = 'img,video,canvas,picture{filter:contrast(1.08) saturate(1.06) brightness(1.02)!important;}';
        (document.head || document.documentElement).appendChild(s);
      }
      return true;
    })();
    """#

    static let disableLucidMode = #"""
    (function() {
      var s = document.getElementById('oriel-lucid-mode');
      if (s) s.remove();
      return true;
    })();
    """#
}
