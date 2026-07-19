# Oriel Engine — CEF binary distribution (Git LFS)

This folder holds the **pinned Chromium Embedded Framework (CEF) Standard**
archive used by Oriel Engine on Mac. It is stored with **Git LFS** so the
binary lives in the GitHub repo without bloating regular git history.

| File | Arch | Chromium |
|------|------|----------|
| `cef_binary_144.0.30+…_macosarm64.tar.bz2` | Apple Silicon | 144 |

## Open source split

| Piece | Where | License |
|-------|--------|---------|
| **Oriel Engine glue** (bridge, Helper, host view) | [`Sources/CEF/`](../../Sources/CEF/) | Apache 2.0 (Oriel) |
| **CEF / Chromium binaries** | this folder (LFS) | Upstream CEF / Chromium (see `LICENSE.txt` inside the archive) |

## Clone / build

```bash
git lfs install
git lfs pull          # if the pointer file is present but not the blob
bash Scripts/fetch-cef-macos.sh          # unpacks Vendor/CEF-dist → ~/Library/.../Oriel/CEF
bash Scripts/build-oriel-engine-macos.sh
```

Intel Macs still download from the Spotify CDN (`ORIEL_CEF_ARCH=macosx64`) until an x64 archive is added here.

See [`docs/CEF_NATIVE.md`](../../docs/CEF_NATIVE.md) and [`THIRD_PARTY_NOTICES.md`](../../THIRD_PARTY_NOTICES.md).
