# Oriel — Implementation Plan

**Product:** Oriel  
**Publisher:** [inveil.net](https://inveil.net)  
**Platforms:** iOS, iPadOS, macOS  
**Stack:** Swift, SwiftUI, WKWebView / WebKit

## Naming

**Oriel** is a privacy-focused native browser by **inveil.net**.

An *oriel* is a projecting bay window — a sheltered place to look out at the world. That metaphor fits a calm, private-minded browser: you see the web clearly, from a protected frame of your own.

The name is original product branding (not Safari/Brave, and not Veil). Publisher remains **inveil.net**. Branding, icons, and UI are original.

## Proposed directory structure

```
Oriel/
├── README.md
├── project.yml                 # XcodeGen multiplatform project
├── Oriel.entitlements
├── docs/
│   ├── IMPLEMENTATION_PLAN.md
│   ├── ARCHITECTURE.md
│   ├── PRIVACY_LIMITATIONS.md
│   └── ENTITLEMENTS.md
├── Sources/
│   ├── App/                    # @main, App root, DI composition
│   ├── BrowserCore/            # Session, shared models, URL helpers
│   ├── WebView/                # WKWebView wrapper, coordinator
│   ├── Tabs/                   # TabManager, tab models, overview
│   ├── Navigation/             # Address bar logic, search engines
│   ├── History/                # HistoryStore, entries (Phase 2)
│   ├── Bookmarks/              # BookmarkStore (Phase 2)
│   ├── Downloads/              # DownloadManager (Phase 4)
│   ├── Privacy/                # PrivacySettings, dashboard (Phase 3)
│   ├── ContentBlocking/        # ContentBlockerManager (Phase 3)
│   ├── Settings/               # BrowserSettings
│   ├── Persistence/            # SwiftData / local stores, Keychain
│   └── PlatformUI/             # Adaptive chrome (iPhone / iPad / Mac)
├── Resources/
│   ├── Assets.xcassets
│   └── ContentBlocker/         # Bundled example ruleset JSON
└── Tests/
    ├── OrielTests/
    └── OrielUITests/
```

Modules are source folders in a shared multiplatform app target (not separate frameworks yet). Boundaries are enforced by directory + types. Frameworks can be split later if needed.

## First smallest buildable milestone

**Phase 1a — Single-tab shell**

1. Multiplatform Xcode project (iOS + macOS) via XcodeGen  
2. One `BrowserTab` with `WKWebView`  
3. Combined address / search field  
4. Back, forward, reload / stop  
5. Loading progress  
6. Platform-adaptive chrome (bottom bar on iPhone; toolbar on Mac)  
7. About attribution: “Made by inveil.net”

Success criteria: project builds for iOS Simulator and macOS; user can type a URL or search query and navigate.

## Phase overview

| Phase | Focus | Exit criteria |
|-------|--------|----------------|
| **1** | Architecture, WKWebView, address bar, one tab, adaptive shell | Builds; browse one site |
| **2** | Tabs, overview, bookmarks, history, session restore | Multi-tab + persistence |
| **3** | Private mode, content blocking, privacy dashboard, cookies | Shields usable |
| **4** | Downloads, permissions, find-in-page, desktop site, shortcuts | Feature-complete MVP |
| **5** | Accessibility, tests, performance, App Store readiness | Ship checklist |

## Phase 3 status

Implemented:

- Private tabs (non-persistent `WKWebsiteDataStore`, no history / session restore)
- Bundled example content-blocker ruleset + `ContentBlockerManager` compile pipeline
- Global + per-site shield toggles
- HTTPS upgrade heuristics with counters
- Best-effort blocked-request counts (navigation-level hints; WebKit limitation documented)
- Clear cookies / website data
- Shields dashboard UI (`Shields` button / sheet)

## Non-goals (all phases)

- AI assistant / chatbot / agent  
- Qadbak integration  
- Crypto, rewards, wallets, ads network  
- Custom or alternative browser engines  
- Paywall bypass  
- Account / cloud sync (structure only for later)

## Build & test workflow

After each coherent step:

```bash
cd ~/Projects/Oriel
xcodegen generate
xcodebuild -scheme Oriel -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -scheme Oriel -destination 'platform=macOS' build
```

Manual smoke test: launch → enter `https://example.com` → confirm load, back/forward, reload.
