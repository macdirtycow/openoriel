# Contributing

## Setup

```bash
xcodegen generate
open Oriel.xcodeproj
```

Xcode 16+, iOS 17+ / macOS 14+.

## Patches

- Keep changes focused; avoid unrelated refactors
- Update docs when behaviour changes
- Regenerate filter lists with `Scripts/build_content_blocker.py` (needs AdGuard `ConverterTool`; see `Resources/ContentBlocker/README.md`); keep `NOTICE` accurate

```bash
xcodegen generate
xcodebuild -scheme Oriel -destination 'platform=macOS,arch=arm64' test
```

## License

By contributing, you agree that your contributions are licensed under the Apache License 2.0.
