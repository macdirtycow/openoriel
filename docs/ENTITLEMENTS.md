# Entitlements

Least privilege. Only what browsing needs.

| Capability | Status | Reason |
|------------|--------|--------|
| App Sandbox (macOS) | Required | Mac App Store / notarization baseline |
| Outgoing network client | Required | Load websites |
| Incoming network server | Off | Unused |
| Downloads folder read-write | On | Save downloads |
| User-selected file read-write | On | Import/export, open files |
| Camera / microphone (sandbox) | On | Site media prompts |
| App Groups | Off | No companion extension target yet |
| Associated Domains | Off | No universal links yet |
| Push Notifications | Off | Unused |
| Personal VPN / Network Extension | Off | Out of scope |

Hardened Runtime is expected for notarized macOS builds. Camera, microphone, and location also need Info.plist usage strings (already set in `project.yml`).
