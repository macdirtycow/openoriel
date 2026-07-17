# Oriel vs other browsers — gaps

Oriel is a **native WebKit** browser. Brave, Chrome, and Opera GX are **Chromium**. Safari is WebKit with Apple system integrations Oriel cannot fully replicate. This document is honest about what we can and cannot match.

## Cannot match (platform / product limits)

| Feature | Who has it | Why Oriel cannot fully ship it |
|---------|------------|--------------------------------|
| Chromium engine / Chrome rendering | Brave, Chrome, Opera GX | iOS App Store requires WebKit; macOS Oriel stays WebKit by design |
| Full Chrome Web Store one-click | Chrome, Brave, Opera | Store install APIs are Chromium-only; macOS can load packages via `WKWebExtension` |
| Brave Rewards / ads / crypto | Brave | Explicit non-goal |
| Opera GX gaming sidebar, CPU/RAM limters, Discord/WhatsApp panels | Opera GX | Product-specific; out of scope |
| iCloud Tabs / Passwords / Keychain deep Safari sync | Safari | Requires Apple private APIs / Safari entitlements |
| Alternative JS engines / V8 | Chromium browsers | WebKit only |

## Added in Phase 7 (this pass)

| Feature | Notes |
|---------|--------|
| Link context menus | Open in New Tab, Copy Link, Download Linked File |
| Favicons | Shown on tabs / overview (DuckDuckGo icon service) |
| Page zoom | In-menu Zoom In / Out / Actual Size |
| Print | System print for the current page |
| Reader Mode | Simplified reading view for article-like pages |
| Force dark on websites | CSS inversion toggle (per tab) |
| Block autoplay | Media requires user gesture (setting) |
| Pin tabs | Pinned tabs stay left; survive casual close prompts in overview |
| Import bookmarks | Netscape/HTML bookmark export from other browsers |

## Still missing / later

| Feature | Priority | Notes |
|---------|----------|--------|
| Larger filter lists (EasyList) | High | Ship import + curated list beyond example rules |
| Password Autofill polish | High | System AutoFill works partially; Associated Domains help |
| Translation | Medium | Apple Translation API on supported OS versions |
| Profiles | Medium | Separate data stores / cookie jars |
| Vertical tabs | Medium | Especially Mac |
| Sync across devices | Low | Account/cloud sync is a non-goal for now |
| Built-in PDF chrome | Medium | WKWebView shows PDFs; dedicated UI later |
| Cast / AirPlay polish | Low | System media routing only |
| Picture-in-Picture controls | Medium | Site + WK supports; toolbar affordance later |

## Product stance

Oriel aims to be a **calm, private-minded Apple-native browser**, not a Chromium clone or Opera GX skin. Feature work prioritizes everyday browsing parity (tabs, menus, zoom, reader, downloads, shields) within honest WebKit limits.
