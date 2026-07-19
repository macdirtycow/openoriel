# Extensions

Chrome/Firefox-style WebExtensions on **macOS 15.4+** and **iOS / iPadOS 18.4+** via `WKWebExtension`.

## Safari extensions

Safari ships two different extension worlds. Only one is portable to Oriel.

| Kind | Extension point | In Oriel? |
|------|-----------------|-----------|
| **Safari Web Extension** | `com.apple.Safari.web-extension` | Yes, when the `.appex` still contains a WebExtension `manifest.json` (+ resources) |
| Legacy Safari App Extension | `com.apple.Safari.extension` | No — native Cocoa code, Safari-only |
| Safari content blocker | `com.apple.Safari.content-blocker` | No — use Oriel Shields instead |

### How import works

1. Classify the `.appex` from its `Info.plist` (`NSExtensionPointIdentifier`).
2. Locate `manifest.json` (usually `Contents/Resources/manifest.json`).
3. Copy **only** the WebExtension resource tree into Oriel’s Extensions folder (not the native appex Mach-O).
4. Soft-normalize Safari-only manifest quirks, then load with `WKWebExtension(resourceBaseURL:)`.
5. If resources are missing but WebKit can still open the bundle, fall back to `WKWebExtension(appExtensionBundle:)` and re-extract.

macOS: **Extensions → Scan Applications for Safari extensions** walks `/Applications` and `~/Applications` for candidate `.appex` packages. You can also pick an `.appex` or Safari Web Extension project folder via **Install from file or folder…**.

iOS / iPadOS: import an `.appex` or a folder that contains `manifest.json` through the file picker. There is no Applications scan.

### Limits

- App Store packages that ship **only** native Safari App Extension code (no WebExtension resources) cannot be imported.
- APIs that talk to Safari-specific native messaging hosts may not work outside Safari.
- WebKit’s permission / API surface is not identical to Chromium.

## Other install paths

| Source | Notes |
|--------|--------|
| Chrome Web Store | On chromewebstore.google.com Oriel relabels install controls to **Add to Oriel** |
| `.zip` / `.crx` | Extensions → Install from file… |
| Unpacked folder | Directory with `manifest.json` |

## UI

| Path | Notes |
|------|--------|
| Manage | Extensions sheet (⌘⇧E on Mac) |
| Popup | macOS: toolbar / NSPopover · iOS: sheet via `popupViewController` when the extension provides one |
| Content scripts | Run in Oriel tabs once the extension is enabled |

## Limits (general)

WebKit’s API surface differs from Chromium. Chrome Apps are not supported. Prefer Manifest V2/V3 packages that WebKit accepts.
