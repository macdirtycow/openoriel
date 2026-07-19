# Oriel

Native browser for iOS, iPadOS, and macOS. Swift, SwiftUI, WebKit.

- Website: https://openoriel.com
- Publisher: https://inveil.net
- Bundle ID: `net.inveil.oriel`

Marketing site source: [`site/`](site/).

## Download

Installers are on [GitHub Releases](https://github.com/macdirtycow/openoriel/releases) and linked from [openoriel.com](https://openoriel.com/#download).

**Mac:** download `Oriel-*-macOS.dmg`, open it, drag Oriel into Applications. First launch: right-click → Open.

**iPhone / iPad:** download `Oriel-*-unsigned.ipa` and sideload with your usual installer (e.g. TrollStore). TestFlight builds: `Scripts/upload-testflight.sh`.

## Build

Needs Xcode 16+, [XcodeGen](https://github.com/yonaskolb/XcodeGen), iOS/iPadOS 17+, macOS 14+ (WebExtensions need iOS/iPadOS 18.4+ or macOS 15.4+).

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
# output: build/ipa/Oriel-<version>-<build>-unsigned.ipa
```

CI also builds that IPA on pushes to `main` (Actions → Build unsigned IPA).

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
| [Extensions](docs/EXTENSIONS.md) | WebExtensions (iOS 18.4+ / macOS 15.4+) |
| [Extension compat](docs/EXTENSION_COMPAT.md) | Chrome/Firefox on iPhone & iPad |
| [Entitlements](docs/ENTITLEMENTS.md) | Sandbox capabilities |
| [App Store](docs/APP_STORE.md) | Release checklist |
| [Content blocker](Resources/ContentBlocker/README.md) | Filter lists |
| [Contributing](CONTRIBUTING.md) | Patches |
| [Security](SECURITY.md) | Vulnerability reports |

## License

Copyright 2025–2026 inveil.net

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
