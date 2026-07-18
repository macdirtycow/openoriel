# Oriel

Native browser for iOS, iPadOS, and macOS — Swift, SwiftUI, WebKit.

- Website: https://openoriel.com
- Publisher: https://inveil.net
- Bundle ID: `net.inveil.oriel`

## Build

Requires Xcode 16+, [XcodeGen](https://github.com/yonaskolb/XcodeGen), iOS/iPadOS 17+, macOS 14+ (WebExtensions need macOS 15.4+).

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

## Documentation

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

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
