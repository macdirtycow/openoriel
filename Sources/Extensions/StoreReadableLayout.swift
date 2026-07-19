import Foundation

/// Injects a compact, readable layout for Chrome Web Store / Firefox AMO on iPhone & iPad.
/// Desktop “Request Desktop Website” is NOT used; install spoofing stays in the store bridges.
enum StoreReadableLayout {
    static let userScriptSource = #"""
    (function () {
      if (window.__orielStoreReadableLayout) return;
      var h = location.hostname;
      var path = (location.pathname || '').toLowerCase();
      var isCWS = h === 'chromewebstore.google.com'
        || ((h === 'chrome.google.com' || h.endsWith('.chrome.google.com'))
            && (path.indexOf('webstore') !== -1 || path.indexOf('/web-store') !== -1));
      var isAMO = h === 'addons.mozilla.org'
        || h === 'addons-dev.allizom.org'
        || h.endsWith('.addons.mozilla.org');
      if (!isCWS && !isAMO) return;
      window.__orielStoreReadableLayout = true;

      function ensureViewport() {
        var head = document.head || document.documentElement;
        var meta = document.querySelector('meta[name="viewport"]');
        if (!meta) {
          meta = document.createElement('meta');
          meta.setAttribute('name', 'viewport');
          head.appendChild(meta);
        }
        // Device-width keeps the store readable; do not lock to a 1200px desktop canvas.
        meta.setAttribute(
          'content',
          'width=device-width, initial-scale=1, maximum-scale=5, viewport-fit=cover'
        );
      }

      function injectCSS() {
        if (document.getElementById('oriel-store-readable-css')) return;
        var style = document.createElement('style');
        style.id = 'oriel-store-readable-css';
        style.textContent = [
          'html { -webkit-text-size-adjust: 100% !important; text-size-adjust: 100% !important; }',
          'body { max-width: 100vw !important; overflow-x: hidden !important; }',
          'img, video, canvas, svg { max-width: 100% !important; height: auto !important; }',
          /* Prefer wrapping long desktop grids instead of horizontal pan */
          '[role="main"], main, #main, .main-content { max-width: 100% !important; }',
          'button, [role="button"], a[role="button"] { min-height: 44px; }',
          /* Keep primary install CTAs easy to tap */
          'button, [role="button"] { font-size: max(14px, 1em) !important; }'
        ].join('\n');
        (document.head || document.documentElement).appendChild(style);
      }

      ensureViewport();
      injectCSS();
      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', function () {
          ensureViewport();
          injectCSS();
        });
      }
    })();
    """#
}
