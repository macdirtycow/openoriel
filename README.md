# Oriel

Native browser for **iPhone, iPad, and Mac**. Swift, SwiftUI, WebKit — with Classic calm chrome or **Oriel Pulse**, Shields, extensions, and (on Mac) dual-engine browsing.

<p align="center">
  <a href="https://openoriel.com"><strong>Website</strong></a>
  ·
  <a href="https://github.com/macdirtycow/openoriel/releases/latest"><strong>Latest release</strong></a>
  ·
  <a href="https://inveil.net">inveil.net</a>
</p>

Bundle ID: `net.inveil.oriel` · Marketing site source: [`site/`](site/)

---

## Download

Installers ship on [GitHub Releases](https://github.com/macdirtycow/openoriel/releases) and are linked from [openoriel.com](https://openoriel.com/#download).

| Platform | Asset | Notes |
|----------|--------|--------|
| **Mac** | `Oriel-*-macOS.dmg` | Open → drag into Applications. First launch: right-click → Open |
| **iPhone / iPad** | `Oriel-*-unsigned.ipa` | Sideload (e.g. TrollStore). Re-sign with your Apple ID |

TestFlight uploads: `Scripts/upload-testflight.sh` (needs Apple Developer Program).

---

## Editions

| | **Classic** | **Pulse** |
|---|-------------|-----------|
| Look | Teal, paper, calm chrome | Obsidian + vermillion signal |
| Extras | — | Pulse Corner, Data/Network Saver, Lucid Mode, ambience, workspace presets, optional Pulse icon |
| Shared | Shields · extensions · page tools · profiles · iCloud sync · (Mac) engines & governors | Same core |

Switch anytime in **Settings → Appearance**.

---

## Engines (Mac)

| Mode | What it is |
|------|------------|
| **Smart** (default) | Per-tab: Compatible for stubborn web apps; WebKit for Apple / captcha-sensitive hosts |
| **WebKit** | Native `WKWebView` |
| **Chromium Compatible** | WebKit paint + Chrome User-Agent / Client Hints — **not Blink** |
| **Chromium Native** | Embedded CEF when installed (`Scripts/fetch-cef-macos.sh`), else managed system Chromium app-window |

**iPhone and iPad stay on WebKit only** — Apple’s rule. Details: [`docs/DUAL_ENGINE.md`](docs/DUAL_ENGINE.md).

---

## Highlights

- **Everyday tools** — tabs & groups, bookmarks, Reading List, history, downloads that persist, find with match counts, mute tab, screenshot, Save as PDF, per-site zoom, Reader, translate
- **Oriel Shields** — content-blocker lists, cosmetics, HTTPS upgrade, tracking-parameter strip, Fire; honest about WebKit limits
- **Extensions** — Chrome Web Store, Firefox Add-ons, Safari `.appex` import via Oriel Store (`WKWebExtension` where the OS allows)
- **Password Vault** (Mac) — optional AES-GCM vault, Keychain-wrapped key, Touch ID / Face ID unlock; system Keychain autofill still available
- **Mac governors** — timer throttle, WebView pool, memory-pressure hibernate (real Oriel-side controls — not fake OS CPU% gauges)
- **iCloud sync** — bookmarks, Reading List, open tabs, limited history, appearance (not vault secrets)

---

## Build

Needs **Xcode 16+**, [XcodeGen](https://github.com/yonaskolb/XcodeGen), iOS/iPadOS 17+, macOS 14+ (WebExtensions need iOS/iPadOS 18.4+ or macOS 15.4+).

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

Local packages:

```bash
bash Scripts/make-macos-dmg.sh
# → build/dmg/Oriel-<version>-<build>-macOS.dmg

bash Scripts/make-unsigned-ipa.sh
# → build/ipa/Oriel-<version>-<build>-unsigned.ipa
```

Optional Mac CEF (in-tab Blink for Chromium Native):

```bash
bash Scripts/fetch-cef-macos.sh
bash Scripts/enable-cef-macos.sh
# Apply Vendor/CEF.xcconfig in Xcode (Mac), embed the framework, clean build.
```

See [`docs/CEF_NATIVE.md`](docs/CEF_NATIVE.md).

CI builds the unsigned IPA on pushes to `main` (Actions → Build unsigned IPA).

### Release tagging

Push a `v*` tag (or run Actions → Release) to attach installers to the GitHub release:

```bash
git tag v1.0.0-N
git push origin v1.0.0-N
```

---

## Project layout

```
Sources/
  App/              # Entry, composition root
  BrowserCore/      # Engines, Smart routing, Chromium Native host
  WebView/          # WKWebView, pool, navigation
  Tabs/ History/ Bookmarks/ Downloads/
  Privacy/          # Shields, fingerprint, Fire
  ContentBlocking/  # Rule compile
  Extensions/       # WKWebExtension, store bridges
  Features/         # Vault, governors, Pulse ambience, zoom, sync, workspaces
  PlatformUI/       # Chrome, start page, Pulse Corner, settings
  Settings/ Persistence/
Resources/          # Icons, content blocker lists
Scripts/            # IPA, DMG, CEF, TestFlight
site/               # openoriel.com
docs/               # Architecture, privacy, dual engine, …
```

---

## Docs

| Doc | Topic |
|-----|--------|
| [Architecture](docs/ARCHITECTURE.md) | Modules and data flow |
| [Dual engine](docs/DUAL_ENGINE.md) | Compatible vs Native honesty |
| [CEF / Blink Native (Mac)](docs/CEF_NATIVE.md) | Fetch, enable, sandbox, updates |
| [Privacy](docs/PRIVACY.md) | Shields and WebKit limits |
| [Product priorities](docs/PRODUCT_PRIORITIES.md) | What ships next |
| [Extensions](docs/EXTENSIONS.md) | WebExtensions |
| [Extension compat](docs/EXTENSION_COMPAT.md) | Chrome / Firefox on phone |
| [Entitlements](docs/ENTITLEMENTS.md) | Sandbox capabilities |
| [App Store](docs/APP_STORE.md) | Release checklist |
| [Content blocker](Resources/ContentBlocker/README.md) | Filter lists |
| [Contributing](CONTRIBUTING.md) | Patches |
| [Security](SECURITY.md) | Vulnerability reports |

---

## License

Copyright 2025–2026 inveil.net

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).

Oriel is independent and not affiliated with Apple, Google, or Opera. “Chromium Compatible” is not Blink.
