# Architecture

Oriel is a single multiplatform app target (XcodeGen). Source folders are modules by convention, not separate frameworks.

## Layout

| Folder | Role |
|--------|------|
| `App` | `@main`, scene, composition root (`AppEnvironment`) |
| `BrowserCore` | Session helpers, URL/search parsing |
| `WebView` | `BrowserWebView`, coordinator, navigation policy, `WebViewPool` (history across tab switches) |
| `Tabs` | Tab model and manager |
| `History` / `Bookmarks` / `Downloads` | Local stores |
| `Privacy` | Shields settings, per-site overrides, persisted stats (session until Fire + lifetime) |
| `ContentBlocking` | Rule compile + YouTube skip script |
| `Extensions` | `WKWebExtension` host, Chrome/Firefox store bridges, Safari `.appex` import, `ManifestCompatNormalizer`, extension themes |
| `Settings` / `Persistence` | Preferences and storage |
| `Features` | Password Vault, Mac governors, Pulse ambience, zoom, sync, workspaces, PiP helpers |
| `PlatformUI` | Shared chrome (toolbars, start page, Pulse Corner, settings sheets) |

## Pattern

SwiftUI views + `@Observable` services. Business logic lives in stores/managers; views stay presentation-focused.

```
Address field → NavigationInput → BrowserTab.load
                                      ↓
Navigation chrome ← NavigationState ← WebViewCoordinator (WKNavigationDelegate)
```

## Platforms

| | iPhone | iPad | macOS |
|--|--------|------|-------|
| Chrome | Compact toolbar | Adaptive | Native toolbar |
| Tabs | Overview | Adaptive | Tab strip / overview |
| Extensions | 18.4+ `WKWebExtension` | 18.4+ `WKWebExtension` | 15.4+ `WKWebExtension` |
| Page engine | WebKit only | WebKit only | WebKit + Chromium Compatible (+ Native when CEF linked); per-site/tab policy, Client Hints, system Chrome hand-off |

Use `#if os(macOS)` / `#if os(iOS)` only where UIKit/AppKit or API differences require it.

See also [`DUAL_ENGINE.md`](DUAL_ENGINE.md). Page-engine preference applies to **Classic and Pulse**.

## Editions

- **Classic** — default Oriel look and behavior (teal / paper).
- **Pulse** — obsidian + vermillion studio chrome, Corner, Data/Network Saver, Lucid Mode, ambience, workspace presets, optional alternate icon. Same privacy model; same page-engine picker.

## Mac-only power tools

- **Password Vault** — AES-GCM vault, Keychain-wrapped key, biometric unlock (`Features/PasswordVaultStore`).
- **Performance governors** — timer throttle, WebView pool cap, memory-pressure hibernate (`Features/MacPerformanceGovernor`). Not fake OS CPU% gauges.
- **Chromium Native host** — CEF when present + `ORIEL_HAS_CEF` build (in-tab Blink), else managed Chromium app-windows (`BrowserCore/ChromiumNativeHost`, `Sources/CEF/`). See [`CEF_NATIVE.md`](CEF_NATIVE.md).

## Trust boundaries

- Page content is untrusted.
- Native bridges from page JS are allowlisted and narrow (e.g. extension install).
- Private tabs use a non-persistent `WKWebsiteDataStore`.
- Secrets belong in the Keychain (system autofill and optional Password Vault).
