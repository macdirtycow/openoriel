# Product priorities

Work this order. Do not skip ahead for polish or marketing until the layer above is solid.

## 1. Stabiliteit

- Geen crashes.
- Snelle opstart.
- Goede tab-herstel (sessie + back/forward per tab).
- Weinig geheugenverbruik.

**Ship status**
- Content-blocker remount bug fixed (lists re-attach without wiping history).
- `WebViewPool` keeps `WKWebView` alive across tab switches (history survives).
- Soft pool cap (12) trims idle tabs under memory pressure.
- Shields JSON load/validate runs off the main actor.
- Session + privacy-stats disk writes are debounced; flush on background / Fire.

## 2. Synchronisatie

- Tabs
- Bladwijzers
- Wachtwoorden (of iCloud Keychain-integratie)
- Geschiedenis

**Ship status**
- iCloud KVS: bookmarks, settings, history (cap 200), open-tab session, Open Later.
- Passwords: system Keychain autofill **and** optional encrypted Oriel Password Vault (AES-GCM, Keychain-wrapped key).
- Next: tighten autofill injection; optional vault sync is intentionally out of scope for KVS.

## 3. Privacy

- Goede tracker- en advertentieblokkering (Shields).
- Duidelijke permissies voor extensies.
- Transparantie over wat lokaal blijft.

**Ship status**
- Large bundled rule lists + YouTube / cosmetic scripts + Fire.
- Gap: extension permissions auto-granted; need install-time review UI.
- Gap: in-app “What Oriel stores” screen (local vs iCloud vs Keychain).

## 4. Eén killer feature

Kandidaten:
- “WebKit-browser met Chrome-, Firefox- én Safari-WebExtension-install.”
- Of een Reader Hub voor rechtmatig toegankelijke content.

**Ship status**
- Install paths for Chrome / Firefox / Safari Web Extensions + themes exist.
- Claim must stay honest: WebKit API ≠ full Chromium/Gecko; legacy Safari App Extensions unsupported.
- Reader Mode exists; **Reader Hub** ships (Reading List with Reader-first open + Continue in Reader).
- **Site Passport** packages per-site engine / zoom / mute / Shields in one sheet.
- Mac **Smart engine chip** shows why WebKit vs Compatible was chosen.

## 5. Polish

- Mooie animaties
- Snelle instellingen
- Onboarding onder 30 seconden
- Aantrekkelijke website met duidelijke screenshots

**Ship status**
- Onboarding ~5 pages with Skip.
- Marketing site has hero; App Store screenshots still open.
- Build 62+: find match counts, mute tab, screenshot/PDF share, download history persistence, per-site zoom.
