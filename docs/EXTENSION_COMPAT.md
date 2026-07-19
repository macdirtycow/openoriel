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

## Chrome Web Store on iPhone / iPad

The store often shows **“not compatible with a phone”** when it sees a mobile Safari UA. Oriel counters that only on CWS hosts:

1. **Desktop Chrome HTTP UA** for `chromewebstore.google.com` (not for Google Search — avoids bot checks).
2. **Desktop content mode** (`preferredContentMode = .desktop`) on iOS navigations to CWS.
3. **JS spoof** of `navigator.userAgent` / `userAgentData` / `platform` / `maxTouchPoints`.
4. **Hide** phone-incompatibility banners.
5. **Rewrite** the native store CTA to localized **Add to Oriel** / **Installed in Oriel** / **Remove from Oriel** (e.g. NL *Verwijderen uit Oriel*) — no extra floating FAB.
6. **Multilingual** (`StoreBridgeI18n`): 60+ locales for CTA detection and Oriel labels.
7. **Installed state**: Oriel injects Chrome store IDs + Firefox AMO slugs into the page on **macOS, iOS, and iPadOS** — including **theme-only** packages.

CRX download already used a desktop Chrome UA; page browsing now matches.

## Firefox Add-ons (AMO) on iPhone / iPad

AMO often shows **“You’ll need Firefox…”** / Download Firefox when it does not see desktop Firefox. Same pattern, Firefox-flavored:

1. **Desktop Firefox HTTP UA** for `addons.mozilla.org` only.
2. **Desktop content mode** on iOS navigations to AMO.
3. **JS spoof** + `InstallTrigger` stub at document-start.
4. **Hide** download-Firefox banners; relabel the native install control to **Add to Oriel** (no floating FAB).
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
