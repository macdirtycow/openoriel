# Extensions

Oriel loads Chrome/Firefox-style WebExtensions on **macOS 15.4+** via Apple’s `WKWebExtension` APIs.

## Chrome Web Store

On [chromewebstore.google.com](https://chromewebstore.google.com/) Oriel:

1. Relabels **Add to Chrome** → **Add to Oriel**
2. Shows a floating **Add to Oriel** control on detail pages
3. Downloads the CRX from Google’s public update endpoint
4. Installs into Oriel’s extension store

Not every extension runs correctly (WebKit ≠ Chromium).

## Other install paths

| Path | Notes |
|------|--------|
| Unpacked folder | Directory with `manifest.json` |
| `.zip` / `.crx` | **Extensions → Install from file…** |
| Enable / disable / remove | Extensions sheet (⌘⇧E) |
| Popup / Open | Toolbar puzzle menu when the extension supports it |

## Limits

- Chrome-only APIs may be missing or stubbed by WebKit
- Chrome Apps are unsupported
- No extension runtime on iPhone / iPad under App Store WebKit rules
