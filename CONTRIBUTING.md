# Contributing

Useful patches welcome. Keep the product honest: WebKit limits stay documented, no fake privacy claims.

## Setup

```bash
xcodegen generate
open Oriel.xcodeproj
```

Build with Xcode 16+ against iOS 17+ / macOS 14+.

## Expectations

- Match existing Swift style; no drive-by refactors
- Prefer small, reviewable PRs
- Update docs when behavior or claims change
- Do not add AI assistants, crypto, rewards, or a second engine
- Filter-list changes: regenerate via `Scripts/convert_easylist_to_webkit.py` and note provenance in `NOTICE`

## Tests

```bash
xcodegen generate
xcodebuild -scheme Oriel -destination 'platform=macOS,arch=arm64' test
```

## License

Contributions are under the Apache License 2.0 (see `LICENSE`).
