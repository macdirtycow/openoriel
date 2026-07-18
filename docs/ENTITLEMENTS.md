# Entitlements

| Capability | Status | Reason |
|------------|--------|--------|
| App Sandbox (macOS) | On | Mac App Store / notarization |
| Outgoing network client | On | Load websites |
| Incoming network server | Off | Unused |
| Downloads folder read-write | On | Downloads |
| User-selected file read-write | On | Import / export / open |
| Camera / microphone (sandbox) | On | Site media prompts |
| iCloud Key-Value Store | On | Sync bookmarks / session / settings |
| App Groups | Off | No companion extension target |
| Associated Domains | Off | Unused |
| Push Notifications | Off | Unused |
| Personal VPN / Network Extension | Off | Unused |
| **Default Browser** (`com.apple.developer.web-browser`) | **Not yet** | Required for iOS / iPadOS Settings → Default Browser App |

Hardened Runtime is expected for notarized macOS builds. Usage strings for camera, microphone, and location are set in `project.yml`.

## Default browser

### macOS

Oriel registers `http` / `https` in `CFBundleURLTypes` and can call `NSWorkspace.setDefaultApplication(at:toOpenURLsWithScheme:)` from Settings → Default browser. No special entitlement is required.

### iOS / iPadOS

Apple only lists apps that hold the managed **Default Browser** entitlement:

1. Request access: [Default Browser entitlement](https://developer.apple.com/contact/request/default-browser/)
2. After approval, add to `Oriel.entitlements`:

```xml
<key>com.apple.developer.web-browser</key>
<true/>
```

3. Keep `CFBundleURLTypes` for `http` / `https` (already in `project.yml`).
4. Ship a build — Oriel appears under Settings → Apps → Default Browser App.

Do **not** add the entitlement before Apple approves it; code signing will fail. The in-app Default browser section already opens Settings and explains this.

Incoming links still work via `onOpenURL` once URL types are registered and the user shares/opens a URL into Oriel.
