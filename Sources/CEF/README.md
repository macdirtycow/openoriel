# Oriel Engine (Mac Blink / CEF)

This folder is **open source** (Apache 2.0, same as the rest of Oriel). It is the Mac-only bridge that hosts real Blink inside Oriel tabs via the Chromium Embedded Framework (CEF).

## What lives in git

| Piece | Path | Notes |
|-------|------|--------|
| Oriel bridge + Helper | this folder | Apache 2.0 — **our** Engine code |
| CEF Standard binary (arm64) | [`Vendor/CEF-dist/`](../../Vendor/CEF-dist/) | Git LFS — upstream Chromium/CEF (~253 MB compressed) |
| Fetch / build / embed scripts | `Scripts/*cef*`, `Scripts/*oriel-engine*` | Unpack LFS archive + build wrapper |

| File here | Role |
|------|------|
| `OrielCEFBridge.h` / `.mm` | ObjC++ bridge |
| `OrielCEFSupport.swift` | Swift helpers / availability |
| `CefWebHostView.swift` | In-tab Engine host |
| `Oriel-Bridging-Header.h` | Bridging header |
| `Helper/process_helper_mac.cc` | CEF helper process entry |

## Local unpack

```bash
git lfs pull
bash Scripts/fetch-cef-macos.sh          # prefers Vendor/CEF-dist, else CDN
bash Scripts/build-oriel-engine-macos.sh
```

Extracted tree: `~/Library/Application Support/Oriel/CEF/` (symlink `Vendor/CEF`). Not committed — rebuildable from the LFS archive.

Release **DMG / PKG** installers already embed the built Engine for end users.

See [`docs/CEF_NATIVE.md`](../../docs/CEF_NATIVE.md) and [`docs/DUAL_ENGINE.md`](../../docs/DUAL_ENGINE.md).
