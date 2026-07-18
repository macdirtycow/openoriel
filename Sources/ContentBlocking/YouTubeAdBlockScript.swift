import Foundation

/// Injected when Oriel Shields are on — skips/hides YouTube player ads.
enum YouTubeAdBlockScript {
    static let source = #"""
    (function () {
      function hostOK() {
        var h = (location.hostname || '').toLowerCase();
        return h === 'www.youtube.com' || h === 'youtube.com' || h === 'm.youtube.com'
          || h === 'youtube-nocookie.com' || h === 'www.youtube-nocookie.com'
          || h.endsWith('.youtube.com') || h.endsWith('.youtube-nocookie.com');
      }
      if (!hostOK()) return;
      window.__orielYouTubeAdBlockKill = false;
      if (window.__orielYouTubeAdBlockInstalled) return;
      window.__orielYouTubeAdBlockInstalled = true;

      function clickSkip() {
        var selectors = [
          '.ytp-ad-skip-button',
          '.ytp-ad-skip-button-modern',
          '.ytp-skip-ad-button',
          '.ytp-ad-skip-button-container button',
          'button.ytp-ad-skip-button-modern',
          '.ytp-ad-skip-button-container .ytp-button',
          '.ytp-ad-skip-button-slot button'
        ];
        for (var i = 0; i < selectors.length; i++) {
          var nodes = document.querySelectorAll(selectors[i]);
          for (var j = 0; j < nodes.length; j++) {
            try { nodes[j].click(); } catch (e) {}
          }
        }
      }

      function nukeAdDom() {
        var kill = document.querySelectorAll([
          'ytd-ad-slot-renderer',
          'ytd-promoted-sparkles-web-renderer',
          'ytd-player-legacy-desktop-watch-ads-renderer',
          'ytd-in-feed-ad-layout-renderer',
          'ytd-action-companion-ad-renderer',
          'ytd-display-ad-renderer',
          'ytd-banner-promo-renderer',
          'ytd-statement-banner-renderer',
          'ytd-promoted-video-renderer',
          '#player-ads',
          '#masthead-ad',
          '#offer-module',
          '.video-ads',
          '.ytp-ad-module',
          '.ytp-ad-overlay-container',
          '.ytp-ad-player-overlay',
          '.ytp-ad-action-interstitial',
          '.ytp-ad-image-overlay'
        ].join(','));
        for (var i = 0; i < kill.length; i++) {
          try { kill[i].remove(); } catch (e) {}
        }
      }

      function skipPlayerAd() {
        var player = document.querySelector('.html5-video-player');
        var video = document.querySelector('video.html5-main-video') || document.querySelector('video');
        if (!player || !video) return;
        var adShowing = player.classList.contains('ad-showing')
          || player.classList.contains('ad-interrupting')
          || player.classList.contains('ad-created')
          || !!document.querySelector('.ytp-ad-player-overlay, .ytp-ad-preview-container, .ytp-ad-text');
        if (!adShowing) {
          try { if (video.playbackRate > 2) video.playbackRate = 1; } catch (e) {}
          return;
        }
        clickSkip();
        try {
          video.muted = true;
          video.playbackRate = 16;
          if (video.duration && isFinite(video.duration) && video.duration > 0) {
            video.currentTime = Math.max(video.currentTime, video.duration - 0.05);
          }
        } catch (e) {}
        clickSkip();
      }

      function tick() {
        if (window.__orielYouTubeAdBlockKill) return;
        if (!hostOK()) return;
        nukeAdDom();
        skipPlayerAd();
      }

      var scheduled = false;
      function schedule() {
        if (scheduled || window.__orielYouTubeAdBlockKill) return;
        scheduled = true;
        setTimeout(function () { scheduled = false; tick(); }, 200);
      }

      tick();
      setInterval(tick, 400);
      document.addEventListener('yt-navigate-finish', tick, true);
      document.addEventListener('yt-page-data-updated', tick, true);
      try {
        var obs = new MutationObserver(schedule);
        obs.observe(document.documentElement, { childList: true, subtree: true });
      } catch (e) {}
    })();
    """#

    static let disableSource = "window.__orielYouTubeAdBlockKill = true;"

    static func shouldInject(for url: URL?) -> Bool {
        guard let host = url?.host?.lowercased() else { return false }
        return host == "youtube.com"
            || host == "www.youtube.com"
            || host == "m.youtube.com"
            || host == "youtube-nocookie.com"
            || host == "www.youtube-nocookie.com"
            || host.hasSuffix(".youtube.com")
            || host.hasSuffix(".youtube-nocookie.com")
    }
}
