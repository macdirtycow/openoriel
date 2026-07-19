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

## Oriel Store (recommended on Mac, iPhone, iPad)

Prefer the native **Oriel Store** over the Chrome / Firefox websites:

- **One search** — users do not pick Chrome vs Firefox; results are a universal catalog
- Each row shows source availability: Chrome / Firefox / Safari
- **Chrome:** CWS HTML + embedded payload (desktop UA only for that fetch)
- **Firefox:** AMO API v5 `addons/search/`
- **Safari:** local `.appex` discovery on Mac + known multi-store seeds
- **Add** auto-picks the best available source (prefer installed → Firefox → Chrome → Safari)
- Installed rows show *Installed from Chrome Web Store* / *Firefox Add-ons* / *Safari*
- **Compatibility badge** per row: Fully supported / Partial support / Not supported (WebKit API fit)
- **Pre-install warning** when APIs are unavailable on WebKit
- **Oriel compatibility** score (estimated community installs + local install counter; seeded until live telemetry)
- Entry: Extensions → Browse Oriel Store, Settings, or overflow menu **Oriel Store**
- Opening the Chrome Web Store or Firefox Add-ons **website** in a tab shows a tip: **Use Oriel Store?**

Store **websites** are not forced to desktop mode/UA. Desktop Chrome UA is kept only for CRX downloads and Oriel Store’s Chrome catalog fetch. Website tabs still get JS bridges (CTA rewrite / sticky Add to Oriel) if the user keeps browsing.

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
