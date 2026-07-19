import Foundation
import WebKit

/// Chrome Client Hints / navigator identity for Chromium Compatible tabs on Mac.
/// Does not replace Blink — WebKit still paints; sites that read UA-CH get Chrome signals.
enum ChromiumIdentityScript {
    static let source = #"""
    (function () {
      if (window.__orielChromiumIdentity) return;
      window.__orielChromiumIdentity = true;
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
                return { brands: this.brands, mobile: this.mobile, platform: this.platform };
              }
            };
          }
        });
      } catch (e) {}
      try {
        if (!window.chrome) {
          window.chrome = { runtime: { id: undefined, connect: function () { return { onMessage: { addListener: function () {} }, postMessage: function () {}, disconnect: function () {} }; }, sendMessage: function () {} } };
        }
      } catch (e) {}
    })();
    """#

    static var userScript: WKUserScript {
        WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }
}
