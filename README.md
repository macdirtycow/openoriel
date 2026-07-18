# Oriel

**A calm view of the web** — a native browser for iPhone, iPad, and Mac.

Built with Swift, SwiftUI, and WebKit. Not a Chromium shell: process-shared WebKit, system materials, and chrome that stays out of the way.

| | |
|--|--|
| Website | [openoriel.com](https://openoriel.com) |
| Publisher | [inveil.net](https://inveil.net) |
| Bundle ID | `net.inveil.oriel` |
| License | Apache 2.0 |

## Features

- **Oriel Shields** — bundled content blockers (EasyList, AdGuard-derived filters, DuckDuckGo tracker hosts), cosmetics, and YouTube ad help.
- **Private tabs** — temporary data store; nothing written to history or session restore.
- **Fire** — clear cookies, site data, and session privacy counters in one place.
- **macOS WebExtensions** — install Chrome Web Store / `.zip` / `.crx` packages (macOS 15.4+).
- **Profiles, Open Later, Focus** — everyday browsing tools without cluttering the first paint.

## Download

macOS builds ship as a **DMG** on [GitHub Releases](https://github.com/macdirtycow/openoriel/releases):

1. Download `Oriel-*-macOS.dmg`
2. Open the disk image and drag **Oriel** into **Applications**
3. First launch: right-click → **Open** (ad-hoc signed release; Gatekeeper may warn once)

iOS / iPadOS: build from source, or use TestFlight when a build is published (`Scripts/upload-testflight.sh`).

### Cut a release (maintainers)

```bash
# Tag must match v* — CI builds the DMG and attaches it to the GitHub Release.
git tag v1.0.0
git push origin v1.0.0
```

Or run **Actions → Release → Run workflow** and pass a tag (e.g. `v1.0.0`).

Local DMG (requires macOS + Xcode):

```bash
bash Scripts/make-macos-dmg.sh
# → build/dmg/Oriel-<version>-<build>-macOS.dmg
```

## Build from source

Requires **Xcode 16+**, [XcodeGen](https://github.com/yonaskolb/XcodeGen), iOS/iPadOS 17+, macOS 14+ (WebExtensions need macOS 15.4+).

```bash
git clone https://github.com/macdirtycow/openoriel.git
cd openoriel
xcodegen generate
open Oriel.xcodeproj
```

```bash
xcodegen generate
xcodebuild -scheme Oriel -destination 'platform=macOS,arch=arm64' build
xcodebuild -scheme Oriel -destination 'platform=macOS,arch=arm64' test
```

Unsigned iOS IPA for sideload tooling:

```bash
bash Scripts/make-unsigned-ipa.sh
```

Marketing site source lives in [`site/`](site/).

## Documentation

| Doc | Topic |
|-----|--------|
| [Architecture](docs/ARCHITECTURE.md) | Source layout |
| [Privacy](docs/PRIVACY.md) | WebKit privacy limits |
| [Extensions](docs/EXTENSIONS.md) | macOS WebExtensions |
| [Entitlements](docs/ENTITLEMENTS.md) | Sandbox capabilities |
| [App Store](docs/APP_STORE.md) | Release / TestFlight checklist |
| [Content blocker](Resources/ContentBlocker/README.md) | Filter lists (AdGuard converter) |
| [Contributing](CONTRIBUTING.md) | Patches |
| [Security](SECURITY.md) | Vulnerability reports |

## License

Copyright 2025–2026 inveil.net

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
