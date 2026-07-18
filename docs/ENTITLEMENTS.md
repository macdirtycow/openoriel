# Entitlements

| Capability | Status | Reason |
|------------|--------|--------|
| App Sandbox (macOS) | On | Mac App Store / notarization |
| Outgoing network client | On | Load websites |
| Incoming network server | Off | Unused |
| Downloads folder read-write | On | Downloads |
| User-selected file read-write | On | Import / export / open |
| Camera / microphone (sandbox) | On | Site media prompts |
| App Groups | Off | No companion extension target |
| Associated Domains | Off | Unused |
| Push Notifications | Off | Unused |
| Personal VPN / Network Extension | Off | Unused |

Hardened Runtime is expected for notarized macOS builds. Usage strings for camera, microphone, and location are set in `project.yml`.
