import Foundation

/// Forces a readable, phone/tablet-width layout on Chrome Web Store / Firefox AMO.
///
/// CWS ships a desktop shell (`.IqBfM { min-width: 1249px }` / `1280px`) that stays
/// tiny when WebKit is in desktop mode or when the JS install spoof makes the SPA
/// treat the client as desktop Chrome. We keep install spoofing in the store bridges
/// and only reflow **store hosts** — never other sites.
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

      var VIEWPORT =
        'width=device-width, initial-scale=1, maximum-scale=5, viewport-fit=cover';

      function ensureViewport() {
        var head = document.head || document.documentElement;
        var meta = document.querySelector('meta[name="viewport"]');
        if (!meta) {
          meta = document.createElement('meta');
          meta.setAttribute('name', 'viewport');
          head.insertBefore(meta, head.firstChild);
        }
        if (meta.getAttribute('content') !== VIEWPORT) {
          meta.setAttribute('content', VIEWPORT);
        }
      }

      function cwsCSS() {
        return [
          /* CWS desktop shell — default is min-width:1249px / 1280px */
          'html.IqBfM, body.IqBfM, .IqBfM {',
          '  min-width: 0 !important;',
          '  width: 100% !important;',
          '  max-width: 100% !important;',
          '}',
          'html, body {',
          '  min-width: 0 !important;',
          '  max-width: 100vw !important;',
          '  overflow-x: hidden !important;',
          '  -webkit-text-size-adjust: 100% !important;',
          '  text-size-adjust: 100% !important;',
          '}',
          /* Detail / browse canvases that assume a wide desktop grid */
          '.yHWa2, .kFwPee, main, [role="main"], #main {',
          '  min-width: 0 !important;',
          '  max-width: 100% !important;',
          '  width: 100% !important;',
          '  box-sizing: border-box !important;',
          '}',
          '@media screen and (max-width: 900px) {',
          '  .IqBfM, .IqBfM * { max-width: 100vw; }',
          '  .IqBfM { padding-left: 12px !important; padding-right: 12px !important; }',
          '  .kFwPee { padding-top: 12px !important; }',
          '  img, video, canvas, svg { max-width: 100% !important; height: auto !important; }',
          '  /* Stack wide desktop rows */',
          '  .IqBfM [style*="display: flex"], .IqBfM [style*="display:flex"] {',
          '    flex-wrap: wrap !important;',
          '  }',
          '  button, [role="button"], a[role="button"] {',
          '    min-height: 44px;',
          '    font-size: max(14px, 1em) !important;',
          '  }',
          '}'
        ].join('\n');
      }

      function amoCSS() {
        return [
          'html, body {',
          '  min-width: 0 !important;',
          '  max-width: 100vw !important;',
          '  overflow-x: hidden !important;',
          '  -webkit-text-size-adjust: 100% !important;',
          '}',
          '.Page-content, .Addon-header, main, [role="main"] {',
          '  min-width: 0 !important;',
          '  max-width: 100% !important;',
          '}',
          'img, video, canvas, svg { max-width: 100% !important; height: auto !important; }',
          'button, [role="button"], a[role="button"] { min-height: 44px; }'
        ].join('\n');
      }

      function injectCSS() {
        var id = 'oriel-store-readable-css';
        var style = document.getElementById(id);
        if (!style) {
          style = document.createElement('style');
          style.id = id;
          (document.head || document.documentElement).appendChild(style);
        }
        var css = isCWS ? cwsCSS() : amoCSS();
        if (style.textContent !== css) style.textContent = css;
      }

      function relaxInlineMinWidths() {
        if (!isCWS || !document.body) return;
        // Body itself often carries IqBfM + inline leftovers from SPA boots.
        document.documentElement.style.setProperty('min-width', '0', 'important');
        document.body.style.setProperty('min-width', '0', 'important');
        document.body.style.setProperty('max-width', '100%', 'important');
        var shells = document.querySelectorAll('.IqBfM, .yHWa2, .kFwPee');
        for (var i = 0; i < shells.length && i < 40; i++) {
          var el = shells[i];
          el.style.setProperty('min-width', '0', 'important');
          el.style.setProperty('max-width', '100%', 'important');
        }
      }

      function apply() {
        ensureViewport();
        injectCSS();
        relaxInlineMinWidths();
      }

      apply();
      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', apply);
      }
      // CWS SPA rewrites <body class> / viewport after boot — keep locking.
      var ticks = 0;
      var timer = setInterval(function () {
        apply();
        ticks += 1;
        if (ticks > 40) clearInterval(timer);
      }, 250);
      try {
        new MutationObserver(function () { apply(); })
          .observe(document.documentElement, {
            childList: true,
            subtree: true,
            attributes: true,
            attributeFilter: ['class', 'style', 'content']
          });
      } catch (e) {}
    })();
    """#
}
