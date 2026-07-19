# App Store / TestFlight checklist

Bundle ID `net.inveil.oriel` · Team `2PP6UH4PWA` · https://openoriel.com · inveil.net

Version **1.0.0 (17)** — bump `CURRENT_PROJECT_VERSION` in `project.yml` for each TestFlight upload, then run `xcodegen generate`.

## Privacy

- [x] Copy aligned with [PRIVACY.md](PRIVACY.md)
- [ ] App Privacy nutrition labels (App Store Connect)
- [x] Privacy policy URL: https://openoriel.com (Settings → Support)
- [x] Uses non-exempt encryption: **No** (`ITSAppUsesNonExemptEncryption`)

## Capabilities

- [x] Sandbox + network client (macOS)
- [x] Downloads / user-selected files (macOS)
- [x] Camera / mic / location usage strings
- [x] http/https URL types for default-browser / open-in-Oriel
- [ ] iOS Default Browser entitlement (`com.apple.developer.web-browser`) — request from Apple before enabling
- [x] No private APIs

## Accessibility

- [x] VoiceOver labels on primary chrome
- [x] Reduce Motion on start page
- [ ] Full VoiceOver pass
- [ ] Increase Contrast check

## Quality

- [x] Unit tests for URL parsing, tabs, privacy helpers, tracking stripper, Open Later queue
- [ ] Release build on device (iPhone, iPad, Mac)
- [ ] Private tab does not write history
- [ ] Shields compile on first launch
- [ ] Extension install on macOS 15.4+

## Metadata (App Store Connect)

- [ ] Screenshots (iPhone 6.7", iPad 12.9", Mac)
- [x] Support URL: https://inveil.net
- [x] Marketing URL: https://openoriel.com
- [ ] Age rating / content rights
- [ ] Review notes: mention Focus Mode, Open Later, tracking-parameter stripping

## TestFlight upload (CLI)

```bash
# Preferred when ASC_ISSUER_ID is set (App Store Connect → Users and Access → Integrations):
export ASC_ISSUER_ID="<uuid>"
bash Scripts/upload-testflight.sh

# Or upload an already-exported IPA:
xcrun altool --upload-app \
  -f build/testflight-upload/Oriel.ipa \
  -t ios \
  --apiKey TXY8G26YBJ \
  --apiIssuer "$ASC_ISSUER_ID"
```

Manual fallback: open `build/Oriel.xcarchive` in Xcode Organizer → Distribute App → App Store Connect → Upload.

## In-app Support links

- Donate: https://paypal.me/macdirtycow
- Support: https://inveil.net
- Privacy: https://openoriel.com
