# Oriel — Entitlements

Least-privilege entitlements for Oriel by [inveil.net](https://inveil.net). Only enable what a feature requires.

## Phase 1 (current)

| Entitlement / capability | Required? | Why |
|--------------------------|-----------|-----|
| App Sandbox (macOS) | **Yes** | Mandatory for Mac App Store; limits file/network surface |
| Outgoing network client (macOS sandbox) | **Yes** | Load websites |
| Incoming network server | **No** | Not needed |
| `com.apple.security.files.downloads.read-write` (macOS) | **Yes (Phase 4)** | Save downloads to the Downloads folder |
| `com.apple.security.files.user-selected.read-write` (macOS) | **Yes (Phase 4)** | Reveal / open user-selected files |
| Camera / Microphone (macOS sandbox) | **Yes (Phase 4)** | Site media permission prompts |
| App Groups | **No for Phase 1** | Only if sharing data with a Content Blocker extension later |
| Keychain sharing / access groups | **No for Phase 1** | Local Keychain for this app is enough until sync/extensions |
| Associated Domains | **No** | No universal links in MVP |
| Push Notifications | **No** | Not used; site notifications are WebKit-mediated where available |
| Personal VPN / Network Extensions | **No** | Out of scope |
| Camera / Microphone usage | Later (permissions phase) | Info.plist usage descriptions when WebRTC permissions are exposed |
| Location usage | Later | Same |

## Planned (Phase 3–4)

| Item | Why |
|------|-----|
| Optional Content Blocker app extension + App Group | If using Safari Content Blocker APIs for system-wide lists; WKContentRuleList in-app may avoid this |
| User-selected file read/write | Downloads and bookmark import/export |
| Hardened Runtime (macOS) | Notarization / App Store |

## Info.plist keys (as features land)

- `NSCameraUsageDescription` — site camera permission  
- `NSMicrophoneUsageDescription` — site microphone permission  
- `NSLocationWhenInUseUsageDescription` — site geolocation  
- Transport security: keep ATS defaults; do **not** broadly disable ATS  

## Explicitly rejected

- Private Apple APIs  
- Disabling certificate validation  
- Entitlements for advertising ID / tracking  
- VPN / packet-tunnel entitlements  

## Review rule

When adding an entitlement, document it here with the feature that needs it and remove it if the feature ships without that capability.
