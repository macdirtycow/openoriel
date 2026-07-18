# App Store / TestFlight checklist

Bundle ID `net.inveil.oriel` · Team `2PP6UH4PWA` · https://openoriel.com · inveil.net

Version **1.0.0 (2)** — bump `CURRENT_PROJECT_VERSION` in `project.yml` for each TestFlight upload, then run `xcodegen generate`.

## Privacy

- [x] Copy aligned with [PRIVACY.md](PRIVACY.md)
- [ ] App Privacy nutrition labels (App Store Connect)
- [x] Privacy policy URL: https://openoriel.com (Settings → Support)
- [x] Uses non-exempt encryption: **No** (`ITSAppUsesNonExemptEncryption`)

## Capabilities

- [x] Sandbox + network client (macOS)
- [x] Downloads / user-selected files (macOS)
- [x] Camera / mic / location usage strings
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

## TestFlight upload (Xcode)

1. Select scheme **Oriel**, destination **Any iOS Device (arm64)**.
2. Product → Archive.
3. Distribute App → App Store Connect → Upload.
4. In App Store Connect → TestFlight, add internal/external testers after processing finishes.
5. Ensure the App Store Connect app record exists for `net.inveil.oriel` before the first upload.

## In-app Support links

- Donate: https://paypal.me/macdirtycow
- Support: https://inveil.net
- Privacy: https://openoriel.com
