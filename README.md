# Oriel

Native browser for iOS, iPadOS, and macOS. Swift, SwiftUI, WebKit.

Site: [openoriel.com](https://openoriel.com) · Publisher: [inveil.net](https://inveil.net)

## What it is

A multiplatform `WKWebView` browser with tabs, bookmarks, history, downloads, private browsing, Shields (content blocking), and — on macOS 15.4+ — WebExtensions including install from the Chrome Web Store.

It is not Chromium, not Safari, and not Brave. Rendering and privacy are bounded by Apple’s WebKit APIs. See [docs/PRIVACY.md](docs/PRIVACY.md).

## Requirements

- Xcode 16+
- iOS / iPadOS 17+, macOS 14+ (extensions need macOS 15.4+)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Build

```bash
git clone https://github.com/macdirtycow/openoriel.git
cd openoriel
xcodegen generate
open Oriel.xcodeproj
```

CLI:

```bash
xcodegen generate
xcodebuild -scheme Oriel -destination 'platform=macOS,arch=arm64' build
xcodebuild -scheme Oriel -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## Shields

Shields compile bundled EasyList/EasyPrivacy-derived `WKContentRuleList` rules plus YouTube-oriented filters and a skip script. Toggle from the toolbar; defaults on.

Regenerate lists: see [Resources/ContentBlocker/README.md](Resources/ContentBlocker/README.md).

## Docs

| Doc | Topic |
|-----|--------|
| [Architecture](docs/ARCHITECTURE.md) | Layout of the source tree |
| [Privacy](docs/PRIVACY.md) | What WebKit can and cannot do |
| [Extensions](docs/EXTENSIONS.md) | macOS WebExtensions / Chrome Web Store |
| [Entitlements](docs/ENTITLEMENTS.md) | Sandbox and capabilities |
| [App Store](docs/APP_STORE.md) | Shipping checklist |
| [Contributing](CONTRIBUTING.md) | How to send changes |
| [Security](SECURITY.md) | How to report issues |

## Non-goals

- Custom browser engine
- AI assistant / chatbot
- Crypto, rewards, or an ads network
- Matching Chromium extension or adblock parity 1:1

## License

Apache License 2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE).
Filter-list provenance is documented in `NOTICE`.
