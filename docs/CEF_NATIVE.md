# Chromium Native / CEF (Mac Blink)

Honest dual-engine notes: [`DUAL_ENGINE.md`](DUAL_ENGINE.md).

## Goal

On **Mac only**, Chromium Native can paint with **real Blink** inside Oriel tabs via the Chromium Embedded Framework (CEF). iPhone and iPad stay WebKit — Apple’s rule.

## The five pieces

| # | Piece | What shipped |
|---|--------|----------------|
| 1 | **Fetch / pin CEF** | `Scripts/fetch-cef-macos.sh` downloads a pinned Standard build (Chromium 144), verifies SHA1, installs framework + headers under `~/Library/Application Support/Oriel/CEF/`, symlinks `Vendor/CEF` |
| 2 | **ObjC++ ↔ Swift bridge** | `Sources/CEF/OrielCEFBridge.h/.mm` — stub always compiles; real `CefInitialize` / `CefBrowserHost` path when `ORIEL_HAS_CEF=1` |
| 3 | **In-app tab host** | `CefWebHostView` + shell routing: Native + ready CEF → Blink view; otherwise managed Chromium window |
| 4 | **Nav / downloads / cookies** | Address/title/loading sync; download callback → Oriel `DownloadManager`; `clearCookiesAndCache` via `CefCookieManager` (separate jar from WebKit — by design) |
| 5 | **Sandbox / notarize / updates** | This doc + entitlements notes; pin bump = re-run fetch script |

## Enable on your Mac

```bash
bash Scripts/fetch-cef-macos.sh          # ~250–300 MB download
bash Scripts/enable-cef-macos.sh         # writes Vendor/CEF.xcconfig
xcodegen generate
open Oriel.xcodeproj
```

Then for the **Mac** destination:

1. Apply `Vendor/CEF.xcconfig` (or set `ORIEL_HAS_CEF=1`, header/framework search paths to `Vendor/CEF`).
2. Embed **Chromium Embedded Framework.framework** into the app’s Frameworks (Copy Files), *or* keep loading from Application Support (runtime detection already checks both).
3. Clean + Run.

Status strings in Settings → Engine / Mac Governors reflect:

- framework missing  
- framework present but binary not built with `ORIEL_HAS_CEF`  
- embedded Blink ready  

## Runtime matrix

| Situation | Behavior |
|-----------|----------|
| iPhone / iPad | Always WebKit |
| Mac, no CEF, Chrome installed | Native → **managed Chromium app-window** (real Blink, separate process) |
| Mac, CEF on disk, app **without** `ORIEL_HAS_CEF` | Status explains rebuild; managed window still available |
| Mac, CEF + `ORIEL_HAS_CEF` build | Native → **in-tab Blink** via CEF |

## Cookies, extensions, Shields

- **Cookies / storage:** CEF uses its own profile (not `WKWebsiteDataStore`). Fire / clear actions should call both WebKit clear and `OrielCEFHost.clearCookiesAndCache` when Native tabs exist.
- **WKWebExtension / Oriel Store:** WebKit-only. CEF tabs do not load Safari/Chrome WebExtensions through Apple’s API. Full Chrome-extension parity inside CEF is a separate project (`cef_extensions`).
- **Shields / content blockers:** `WKContentRuleList` does not apply to CEF. Native tabs rely on site HTTPS and CEF defaults until a CEF request filter is added.

## Sandbox & notarization

CEF spawns helper processes (GPU, renderer, utility). Under App Sandbox this is fragile.

Practical approach for Oriel:

1. **Debug / local Native:** `settings.no_sandbox = true` in the CEF bridge (already set when `ORIEL_HAS_CEF`). Prefer a non-sandboxed Debug Mac entitlement file when embedding CEF.
2. **Release:** either  
   - ship Native as **managed Chromium windows** (sandbox-friendly), or  
   - ship CEF helpers as separate Mach-O helpers with hardened runtime + correct `com.apple.security.cs.disable-library-validation` / inheritance entitlements, and notarize the whole bundle.
3. **Notarize:** `codesign` the framework and helpers, then `notarytool` the `.app` / DMG. CEF’s Spotify builds are unsigned for your Team — you must re-sign.

See also Apple’s hardened runtime docs and CEF’s Mac distribution notes in the binary tree (`README.txt`).

## Updating Chromium / CEF

1. Bump `PIN_VERSION` + SHA1s in `Scripts/fetch-cef-macos.sh` from [cef-builds.spotifycdn.com](https://cef-builds.spotifycdn.com/index.html) (`index.json` → `macosarm64` / `macosx64`, `type: standard`, non-beta).
2. Re-run fetch + enable + clean build.
3. Smoke-test: Native tab loads `chrome://version` / `https://example.com`, back/forward, download, Fire clears CEF cookies.

## What this is not

- Not Blink on iOS.  
- Not “Chromium Compatible” (that remains WebKit + Chrome UA).  
- Not a full Chrome clone (extensions, sync, autofill parity).
