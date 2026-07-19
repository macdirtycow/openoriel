# Dual engine strategy (WebKit + Chromium)

Oriel’s goal: **best of both worlds** without breaking Apple rules or pretending Chromium runs on iPhone.

The page-engine preference is **edition-agnostic**: it works in **Classic Oriel** and **Oriel Pulse** the same way.

## Platform rules

| Platform | Allowed engines | Oriel behavior |
|----------|-----------------|----------------|
| **iPhone / iPad** | **WebKit only** (App Store / BrowserEngineKit policy) | Always WebKit. Chromium Native is unavailable. |
| **Mac** | WebKit and/or Chromium | WebKit default. Optional **Chromium Compatible** (Chrome UA on WebKit) now. **Chromium Native** (CEF) when a framework is linked later. |

## Modes in Settings → Appearance → Page engine

Available whether you are on Classic or Pulse:

1. **WebKit** — system integration, Shields, `WKWebExtension`, Private tabs, Keychain.
2. **Chromium Compatible** (Mac) — still WebKit rendering, but Chrome desktop User-Agent and extension-friendly packaging. Helps stubborn sites and Chrome-oriented add-ons without shipping Chromium.
3. **Chromium Native** (Mac, future) — real Chromium/CEF process when `OrielChromium.framework` / CEF is linked into the Mac target. Until then Oriel falls back to Compatible and can **Open in system Chrome**.

Quick actions (Classic + Pulse on Mac):

- **Page → Open in System Chrome…**
- **Page → Use Chromium Compatible UA** / **Use WebKit UA**
- Pulse Corner also exposes Open in system Chrome when Pulse is on

## Why not Chromium on iOS?

Apple requires browsers that navigate the open web on iOS/iPadOS to use WebKit. Shipping CEF or Blink there is not App Store–viable for a general browser.

## Roadmap for Native Chromium (Mac)

1. Add an optional Xcode target / SPM binary that embeds CEF or a thin Chromium shell.
2. Implement `PageRenderingEngine` with a CEF-backed Mac view beside `WKWebView`.
3. Per-tab engine picker: WebKit for privacy/system sites, Chromium for extension-heavy or Chrome-only sites.
4. Keep Shields/content blockers WebKit-side; map what is possible under Chromium separately.

## Honesty

“Chromium Compatible” is **not** Blink. It is the practical bridge today. Settings and About show the resolved engine name so Classic and Pulse users see the same truth.
