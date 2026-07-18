# Oriel — Web Extensions

Oriel loads **Chrome/Firefox-style WebExtensions** on **macOS 15.4+** using Apple’s `WKWebExtension` APIs.

## Chrome Web Store — Add to Oriel

On [chromewebstore.google.com](https://chromewebstore.google.com/) Oriel:

1. Rewrites **Add to Chrome** → **Add to Oriel**
2. Shows a floating **Add to Oriel** button on extension detail pages
3. Downloads the CRX from Google’s public update endpoint (same family of URL Chromium/Brave use)
4. Installs it into Oriel’s extension store

Not every extension will run perfectly (WebKit ≠ Chromium), but install-from-store works the Brave-like way.

## Also supported

| Capability | Notes |
|------------|--------|
| Install unpacked folder | Directory with `manifest.json` |
| Install `.zip` / `.crx` | Via **Extensions → Install from file…** |
| Enable / disable / remove | Extensions sheet (⌘⇧E) |

## Limits

| Limitation | Why |
|------------|-----|
| Some Chrome-only APIs | WebKit’s extension API surface differs from Chromium |
| Chrome Apps | Deprecated by Google |
| iPhone / iPad | No Oriel extension runtime under App Store WebKit rules |

## Privacy

Extensions receive the host permissions in their manifest at install time. Only install extensions you trust.
