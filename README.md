# Oriel

Native browser for iOS, iPadOS, and macOS. Swift, SwiftUI, WebKit.

- Website: https://openoriel.com
- Publisher: https://inveil.net
- Bundle ID: `net.inveil.oriel`

Marketing site source: [`site/`](site/).

## Download (macOS)

DMG builds are on [GitHub Releases](https://github.com/macdirtycow/openoriel/releases).

1. Download `Oriel-*-macOS.dmg`
2. Open it and drag Oriel into Applications
3. First launch: right-click Oriel, then Open (Gatekeeper may warn once)

iOS / iPadOS: build from source, or use TestFlight when a build is up (`Scripts/upload-testflight.sh`).

## Build

Needs Xcode 16+, [XcodeGen](https://github.com/yonaskolb/XcodeGen), iOS/iPadOS 17+, macOS 14+ (WebExtensions need macOS 15.4+).

```bash
git clone https://github.com/macdirtycow/openoriel.git
cd openoriel
xcodegen generate
open Oriel.xcodeproj
```

```bash
xcodegen generate
xcodebuild -scheme Oriel -destination 'platform=macOS,arch=arm64' build
```

Local DMG:

```bash
bash Scripts/make-macos-dmg.sh
# output: build/dmg/Oriel-<version>-<build>-macOS.dmg
```

Unsigned iOS IPA (sideload):

```bash
bash Scripts/make-unsigned-ipa.sh
```

### Release tagging

Push a `v*` tag (or run Actions → Release) to build the DMG and attach it to the GitHub release:

```bash
git tag v1.0.0
git push origin v1.0.0
```

## Docs

| | |
|--|--|
| [Architecture](docs/ARCHITECTURE.md) | Source layout |
| [Privacy](docs/PRIVACY.md) | WebKit privacy limits |
| [Extensions](docs/EXTENSIONS.md) | macOS WebExtensions |
| [Entitlements](docs/ENTITLEMENTS.md) | Sandbox capabilities |
| [App Store](docs/APP_STORE.md) | Release checklist |
| [Content blocker](Resources/ContentBlocker/README.md) | Filter lists |
| [Contributing](CONTRIBUTING.md) | Patches |
| [Security](SECURITY.md) | Vulnerability reports |

## License

Copyright 2025–2026 inveil.net

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
