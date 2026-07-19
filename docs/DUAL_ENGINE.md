# Dual engine strategy (WebKit + Chromium)

Oriel’s goal: **best of both worlds** without breaking Apple rules or pretending Chromium runs on iPhone.

The page-engine preference is **edition-agnostic**: it works in **Classic Oriel** and **Oriel Pulse** the same way.

## Smart (best per tab) — Mac default

Each tab resolves its own concrete engine from the **destination host** of that tab’s navigation:

1. Per-tab override (Page → Page Engine), if set
2. Per-site preference (Shields / Chromium features)
3. **Smart pick:** Chromium Compatible for stubborn web apps (Meet, Teams, Discord, Docs, …); WebKit for everything else — especially Apple ID / captcha-sensitive hosts
4. Otherwise the fixed global mode (WebKit / Compatible / Native)

Two tabs can differ at the same time: Tab A on `meet.google.com` → Chromium Compatible; Tab B on `apple.com` → WebKit.

## Platform rules

| Platform | Allowed engines | Oriel behavior |
|----------|-----------------|----------------|
| **iPhone / iPad** | **WebKit only** | Always WebKit. |
| **Mac** | Smart / WebKit / Chromium Compatible / Native | Smart is the default. |

## Chromium Native (Mac)

| Mode | When | What runs |
|------|------|-----------|
| **Embedded CEF** | Framework on disk **and** app built with `ORIEL_HAS_CEF` | In-tab Blink (`CefWebHostView`) |
| **Managed Chromium** | No ready CEF host, but Chrome/Brave/Edge/Arc installed | Real Chromium process in an app-mode window |

Setup: `Scripts/fetch-cef-macos.sh` → `Scripts/enable-cef-macos.sh` → rebuild Mac. Details: [`CEF_NATIVE.md`](CEF_NATIVE.md).

“Chromium Compatible” remains **WebKit paint + Chrome UA/Client Hints**.

## Mac governors

CPU / RAM governors throttle page timers and cap live `WKWebView`s under memory pressure. They are real Oriel-side controls — not a fake OS CPU% widget and not a kernel quota.
