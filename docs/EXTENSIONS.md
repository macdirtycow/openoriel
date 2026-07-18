# Extensions

Chrome/Firefox-style WebExtensions on **macOS 15.4+** and **iOS / iPadOS 18.4+** via `WKWebExtension`.

## Safari App Store extensions

Safari extensions sold or distributed through the App Store as Safari App Extensions (`.appex`) are **not loadable** in Oriel (or any third-party `WKWebView` browser). Apple binds those packages to Safari.

What *does* work:

| Source | Notes |
|--------|--------|
| Chrome Web Store | On chromewebstore.google.com Oriel relabels install controls to **Add to Oriel** |
| `.zip` / `.crx` | Extensions → Install from file… |
| Unpacked folder | Directory with `manifest.json` |
| Safari Web Extension **source** | Project / Resources folders that still contain a WebExtension `manifest.json` |

## Install paths

| Path | Notes |
|------|--------|
| Manage | Extensions sheet (⌘⇧E on Mac) |
| Popup | macOS: toolbar / NSPopover · iOS: sheet via `popupViewController` when the extension provides one |
| Content scripts | Run in Oriel tabs once the extension is enabled |

## Limits

WebKit’s API surface differs from Chromium. Chrome Apps are not supported. Prefer Manifest V2/V3 packages that WebKit accepts.
