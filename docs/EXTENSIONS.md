# Extensions

Chrome/Firefox-style WebExtensions on macOS 15.4+ via `WKWebExtension`.

## Chrome Web Store

On chromewebstore.google.com Oriel relabels install controls to **Add to Oriel**, downloads the CRX from Google’s update endpoint, and installs into the local extension store.

## Install paths

| Path | Notes |
|------|--------|
| Unpacked folder | Directory with `manifest.json` |
| `.zip` / `.crx` | Extensions → Install from file… |
| Manage | Extensions sheet (⌘⇧E); enable / disable / remove |
| Popup | Toolbar puzzle menu when supported |

## Limits

WebKit’s API surface differs from Chromium. Unsupported on iPhone/iPad. Chrome Apps are not supported.
