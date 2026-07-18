import Foundation

enum PageEnhancementScripts {
    /// Lightweight reader: extract main text and restyle.
    static let readerMode = #"""
    (function() {
      if (document.getElementById('oriel-reader-root')) {
        location.reload();
        return 'off';
      }
      const article = document.querySelector('article') || document.querySelector('main') || document.body;
      const title = document.title || '';
      const clone = article.cloneNode(true);
      clone.querySelectorAll('script, style, nav, footer, iframe, noscript, svg').forEach(n => n.remove());
      const text = clone.innerText || clone.textContent || '';
      if (text.trim().length < 80) { return 'too-short'; }
      function esc(s) {
        return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
      }
      const html = '<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">'
        + '<title>' + esc(title) + '</title><style>'
        + 'body{margin:0;font:21px/1.6 -apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;background:#f7f4ef;color:#1c1b19;padding:8vh 6vw;}'
        + '@media(prefers-color-scheme:dark){body{background:#161513;color:#f2efe8;}}'
        + '#oriel-reader-root{max-width:40rem;margin:0 auto;}h1{font-size:1.8rem;line-height:1.25;margin:0 0 1.2rem;}'
        + 'p{margin:0 0 1rem;}img{max-width:100%;height:auto;border-radius:8px;}a{color:#0b6bcb;}'
        + '</style></head><body><div id="oriel-reader-root"><h1>' + esc(title) + '</h1>'
        + clone.innerHTML + '</div></body></html>';
      document.open(); document.write(html); document.close();
      return 'on';
    })();
    """#

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
}
