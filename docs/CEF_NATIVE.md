# Oriel Engine / CEF (Mac Blink)

Honest dual-engine notes: [`DUAL_ENGINE.md`](DUAL_ENGINE.md).

## Goal

On **Mac only**, **Oriel Engine** paints with **real Blink** inside Oriel tabs via the Chromium Embedded Framework (CEF). Release DMGs bundle the engine by default (`ORIEL_BUNDLE_CEF=1`). iPhone and iPad stay WebKit — Apple’s rule.

## What ships

| Piece | Path |
|--------|------|
| Fetch / pin CEF | `Scripts/fetch-cef-macos.sh` — pinned Standard Chromium 144, SHA1, installs under `~/Library/Application Support/Oriel/CEF/` (Release + headers + wrapper sources; no Debug/tests). Pin metadata lives in `oriel-meta/` (never a root `VERSION` file — that breaks C++ `<version>` on macOS). |
| Build Engine | `Scripts/build-oriel-engine-macos.sh` — `libcef_dll_wrapper.a` + `Oriel Helper*.app` + `Vendor/CEF.xcconfig` |
| Embed into .app | `Scripts/embed-oriel-engine-macos.sh` — versioned framework layout + helpers under `Contents/Frameworks/` |
| DMG | `Scripts/make-macos-dmg.sh` — fetch → build → compile with `ORIEL_HAS_CEF` → embed → DMG |
| Bridge | `Sources/CEF/OrielCEFBridge.*` + `CefWebHostView` |
| Helper source | `Sources/CEF/Helper/process_helper_mac.cc` (compiled by the Engine script, not the iOS target) |

## Local Mac build

```bash
bash Scripts/fetch-cef-macos.sh          # ~250 MB download (once)
bash Scripts/build-oriel-engine-macos.sh # wrapper + helpers
bash Scripts/make-macos-dmg.sh           # full Release app + DMG with Engine
```

Slim WebKit-only DMG (no Engine):

```bash
ORIEL_BUNDLE_CEF=0 bash Scripts/make-macos-dmg.sh
```

Needs: Xcode 16+, cmake, ninja (`brew install cmake ninja`).

## Runtime matrix

| Situation | Behavior |
|-----------|----------|
| iPhone / iPad | Always WebKit |
| Mac DMG with Engine (default) | Oriel Engine → **in-tab Blink** |
| Mac, no CEF in binary, Chrome installed | Oriel Engine → **managed Chromium app-window** |
| Mac, CEF on disk, app **without** `ORIEL_HAS_CEF` | Status explains rebuild; managed window still available |

## Cookies, extensions, Shields

- **Cookies / storage:** CEF uses its own profile (not `WKWebsiteDataStore`). Fire clears WebKit and CEF when Engine is linked.
- **WKWebExtension / Oriel Store:** WebKit-only.
- **Shields / content blockers:** `WKContentRuleList` does not apply to CEF tabs yet.

## Sandbox & notarization

Engine builds use `Resources/Oriel-macOS-Engine.entitlements` (App Sandbox **off**) so CEF helpers can run. Ad-hoc Release DMGs are not notarized; Gatekeeper may require right-click → Open once.

For notarized distribution later: re-sign the framework, every Helper, and the main app with your Developer ID, then `notarytool` the DMG.

## Updating Chromium / CEF

1. Bump `PIN_VERSION` + SHA1s in `Scripts/fetch-cef-macos.sh` from [cef-builds.spotifycdn.com](https://cef-builds.spotifycdn.com/index.html).
2. Re-run fetch + `build-oriel-engine-macos.sh` + DMG.
3. Smoke-test: Oriel Engine tab loads a page, back/forward, download, Fire clears CEF cookies.

## What this is not

- Not Blink on iOS.  
- Not “Chromium Compatible” (that remains WebKit + Chrome UA).  
- Not a full Chrome clone (extensions, sync, autofill parity inside CEF).
