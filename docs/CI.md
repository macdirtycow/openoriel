# CI

| Workflow | Status intent |
|----------|----------------|
| Build unsigned IPA | Must be green |
| Release (tags `v*`) | Must be green (DMG) |
| CodeQL (advanced workflow) | Build must work; SARIF upload soft-fails if Default setup is on |

## Fix red CodeQL from GitHub Default setup

1. Open the repo on GitHub  
2. **Settings → Code security → Code scanning**  
3. Under **CodeQL default setup** click **Disable**  

Keep the advanced workflow in `.github/workflows/codeql.yml`.

ZIPFoundation is vendored in `Sources/ThirdParty/ZIPFoundation` (no SwiftPM).
