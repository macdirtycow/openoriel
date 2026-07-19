# Chrome / Firefox extensions on iOS & iPadOS

## Verdict

**Yes — with WebKit’s built-in host, not a Chromium/Gecko engine.**

From **iOS / iPadOS 18.4** (and macOS 15.4), Apple’s `WKWebExtension` API lets any WebKit browser load standard WebExtension packages (`manifest.json` + resources). Oriel already uses that host on iPhone, iPad, and Mac.

A full “run Chromium extensions exactly like Chrome” or “run Gecko add-ons exactly like Firefox” converter is **not possible** inside an App Store WebKit app: you cannot ship Chromium or Gecko, and you cannot polyfill every privileged API. What *is* possible — and what Oriel ships — is a **built-in packaging/manifest compat layer** plus theme import.

## What works today in Oriel

| Path | iOS / iPadOS 18.4+ | Notes |
|------|--------------------|--------|
| `.zip` WebExtension | Yes | File importer |
| Chrome `.crx` | Yes | Header stripped → ZIP |
| Firefox `.xpi` | Yes | ZIP |
| Chrome Web Store | Yes | Download + stage |
| Firefox AMO | Yes | “Add to Oriel” bridge |
| Safari Web Extension `.appex` | Yes | Peel `Resources/` tree |
| Scan `/Applications` for Safari | macOS only | No Applications scan on iOS |
| Extension themes (`theme` in manifest) | Yes | Colors + optional NTP image |

## Oriel Store (recommended on iPhone / iPad)

The Chrome Web Store **desktop catalog** does not reflow well on a phone. Prefer the native **Oriel Store**:

- **Chrome:** public CWS search/category HTML → list (desktop UA fetch)
- **Firefox:** AMO API v5 `addons/search/`
- Extensions and themes; install via existing CRX/XPI pipeline
- Entry: Extensions → Browse Oriel Store, Settings, or overflow menu **Oriel Store**
- Opening the Chrome Web Store or Firefox Add-ons **website** in a tab shows a one-time tip: **Use Oriel Store?**

## Chrome Web Store website on iPhone / iPad

When opening the website store, Oriel still:

1. **Desktop Chrome UA + desktop content mode on CWS only** (mobile UA = marketing page with no catalog).
2. **Readable layout** best-effort (`StoreReadableLayout`).
3. **JS spoof** + hide desktop-only banners + sticky **Add to Oriel** on detail pages.
4. **CRX downloads** use desktop Chrome UA; multilingual CTA rewrite + installed-state injection (incl. themes).

## Firefox Add-ons (AMO) on iPhone / iPad

Prefer **Oriel Store** (Firefox tab). Website AMO still gets:

1. **Mobile Safari UA** for AMO browsing; XPI download keeps its own request headers.
2. **Mobile content mode** unless the user requests desktop.
3. **JS spoof** + `InstallTrigger` stub at document-start.
4. **Hide** download-Firefox banners; relabel the native install control to **Add to Oriel** / **Remove from Oriel**.
5. Same shared **`StoreBridgeI18n`** catalog for localized Firefox CTAs and Oriel labels.

## Built-in compat (`ManifestCompatNormalizer`)

Runs on every staged package (CRX / XPI / zip / Safari extract):

- `browser_action` / `page_action` → `action`
- Force non-persistent backgrounds; prefer `service_worker` when both shapes exist
- MV3 `scripts` → `service_worker` when needed
- Drop Safari `browser_specific_settings.safari` and legacy Firefox `applications`
- Strip permissions WebKit cannot host (`debugger`, `proxy`, `nativeMessaging`, …)
- Drop `options_ui.chrome_style`

This improves **load acceptance**. It does **not** invent missing APIs.

## Hard limits (Apple / WebKit)

1. **WebKit ≠ Chromium ≠ Gecko** — APIs and permissions differ; many Chrome/Firefox-only features stay unsupported.
2. **No alternate browser engine** — on iOS, browsers must use WebKit; Chrome and Firefox for iOS are also WebKit-based and cannot host full desktop-extension engines either.
3. **OS floor** — Oriel’s extension host requires **18.4+** at runtime (app deployment target may be lower; UI shows unsupported below that).
4. **Themes** — Oriel maps colors / NTP images into its own chrome; it does not emulate Chrome’s full theme engine.

## Sources

- [WebKit Features in Safari 18.4 — Web Extensions](https://webkit.org/blog/16574/webkit-features-in-safari-18-4/)
- [Safari 18.4 Release Notes — WKWebExtension](https://developer.apple.com/documentation/safari-release-notes/safari-18_4-release-notes)
- [WKWebExtension](https://developer.apple.com/documentation/webkit/wkwebextension)
