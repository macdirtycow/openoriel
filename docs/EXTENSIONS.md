# Extensions

Chrome/Firefox-style WebExtensions on **macOS 15.4+** and **iOS / iPadOS 18.4+** via `WKWebExtension`.

See also: [Extension compatibility (iOS research)](EXTENSION_COMPAT.md).

## Install sources

| Source | Notes |
|--------|--------|
| Chrome Web Store | Install controls become **Add to Oriel** (on iPhone/iPad Oriel spoofs desktop Chrome for the store only, so “not compatible with a phone” is suppressed) |
| Firefox Add-ons (AMO) | Install / theme buttons become **Add to Oriel** / **Add theme to Oriel** (on iPhone/iPad Oriel spoofs desktop Firefox on AMO only, so “You’ll need Firefox…” does not block install) |
| `.zip` / `.crx` / `.xpi` | Extensions → Install from file… (iOS + macOS) |
| Unpacked folder | Directory with `manifest.json` |
| Safari Web Extension `.appex` | Peel WebExtension resources (macOS can also scan Applications) |

## Built-in compat

Before load, Oriel soft-rewrites manifests (`ManifestCompatNormalizer`) so more Chrome/Firefox/Safari packages validate under WebKit — action aliases, background shape, Safari BSS, unsafe permissions. This is packaging compat, not a full API shim.

## Safari extensions

| Kind | Extension point | In Oriel? |
|------|-----------------|-----------|
| **Safari Web Extension** | `com.apple.Safari.web-extension` | Yes, when the `.appex` still contains `manifest.json` |
| Legacy Safari App Extension | `com.apple.Safari.extension` | No |
| Safari content blocker | `com.apple.Safari.content-blocker` | No — use Oriel Shields |

macOS: **Extensions → Scan Applications for Safari extensions**.

## Themes (Chrome / Firefox / Safari)

Packages whose `manifest.json` includes a top-level `"theme"` block are imported as **Oriel extension themes**:

1. Parse `theme.colors` (Chrome RGB arrays or Firefox CSS colors) and optional `theme.images`.
2. Store under Application Support → `Oriel/ExtensionThemes`.
3. Apply accent + chrome / start-page background (and NTP image when present).
4. Theme-only packages (no background / content scripts / action) skip `WKWebExtension` load.
5. Hybrid packages install both the theme and the functional extension.

Pick themes under **Extensions → Themes** or **Settings → Appearance → Extension themes**.

## Limits

- WebKit’s API surface differs from Chromium / Gecko.
- Legacy native Safari App Extensions cannot leave Safari.
- Firefox add-ons that need privileged Gecko APIs may not run fully in Oriel.
- Theme mapping covers colors + NTP image; Chrome’s full tint / frame-image engine is not emulated.
