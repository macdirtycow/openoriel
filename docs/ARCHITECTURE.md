# Architecture

Oriel is a single multiplatform app target (XcodeGen). Source folders are modules by convention, not separate frameworks.

## Layout

| Folder | Role |
|--------|------|
| `App` | `@main`, scene, composition root (`AppEnvironment`) |
| `BrowserCore` | Session helpers, URL/search parsing |
| `WebView` | `WKWebView` wrapper, coordinator, navigation policy |
| `Tabs` | Tab model and manager |
| `History` / `Bookmarks` / `Downloads` | Local stores |
| `Privacy` | Shields settings, per-site overrides, persisted stats (session until Fire + lifetime) |
| `ContentBlocking` | Rule compile + YouTube skip script |
| `Extensions` | `WKWebExtension` host, Chrome Web Store bridge, Safari Web Extension `.appex` import |
| `Settings` / `Persistence` | Preferences and storage |
| `PlatformUI` | Shared chrome (toolbars, start page, sheets) |

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
| Extensions | — | — | 15.4+ `WKWebExtension` |

Use `#if os(macOS)` / `#if os(iOS)` only where UIKit/AppKit or API differences require it.

## Trust boundaries

- Page content is untrusted.
- Native bridges from page JS are allowlisted and narrow (e.g. extension install).
- Private tabs use a non-persistent `WKWebsiteDataStore`.
- Secrets belong in the Keychain.
