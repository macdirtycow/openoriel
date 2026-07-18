import Foundation

/// Injected when Oriel Shields are on — skips/hides YouTube player ads (WebKit cannot match Brave’s engine 1:1).
enum YouTubeAdBlockScript {
    static let source = #"""
    (function () {
      if (window.__orielYouTubeAdBlock) return;
      window.__orielYouTubeAdBlock = true;

      function hostOK() {
        var h = location.hostname;
        return h === 'www.youtube.com' || h === 'youtube.com' || h === 'm.youtube.com'
          || h === 'youtube-nocookie.com' || h === 'www.youtube-nocookie.com'
          || h.endsWith('.youtube.com');
      }
      if (!hostOK()) return;

      function clickSkip() {
        var selectors = [
          '.ytp-ad-skip-button',
          '.ytp-ad-skip-button-modern',
          '.ytp-skip-ad-button',
          '.ytp-ad-skip-button-container button',
          'button.ytp-ad-skip-button-modern'
        ];
        for (var i = 0; i < selectors.length; i++) {
          var btn = document.querySelector(selectors[i]);
          if (btn) { try { btn.click(); } catch (e) {} }
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
          '#player-ads',
          '#masthead-ad',
          '.video-ads',
          '.ytp-ad-module',
          '.ytp-ad-overlay-container',
          '.ytp-ad-player-overlay',
          '.ytp-ad-action-interstitial'
        ].join(','));
        for (var i = 0; i < kill.length; i++) {
          try { kill[i].remove(); } catch (e) {}
        }
      }

      function skipPlayerAd() {
        var player = document.querySelector('.html5-video-player');
        var video = document.querySelector('video.html5-main-video, video');
        if (!player || !video) return;
        var adShowing = player.classList.contains('ad-showing')
          || player.classList.contains('ad-interrupting')
          || !!document.querySelector('.ytp-ad-player-overlay, .ytp-ad-preview-container');
        if (!adShowing) return;
        clickSkip();
        try {
          if (video.duration && isFinite(video.duration) && video.duration > 0 && video.currentTime < video.duration - 0.25) {
            video.currentTime = Math.max(0, video.duration - 0.1);
            video.playbackRate = 16;
            video.muted = true;
          }
        } catch (e) {}
        clickSkip();
      }

      function tick() {
        if (!hostOK()) return;
        nukeAdDom();
        skipPlayerAd();
      }

      var scheduled = false;
      function schedule() {
        if (scheduled) return;
        scheduled = true;
        setTimeout(function () { scheduled = false; tick(); }, 250);
      }

      tick();
      setInterval(tick, 500);
      document.addEventListener('yt-navigate-finish', tick, true);
      var obs = new MutationObserver(schedule);
      obs.observe(document.documentElement, { childList: true, subtree: true });
    })();
    """#

    static func shouldInject(for url: URL?) -> Bool {
        guard let host = url?.host?.lowercased() else { return false }
        return host == "youtube.com"
            || host == "www.youtube.com"
            || host == "m.youtube.com"
            || host == "youtube-nocookie.com"
            || host == "www.youtube-nocookie.com"
            || host.hasSuffix(".youtube.com")
    }
}
