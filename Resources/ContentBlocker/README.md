# Content blocker lists

Built with [AdGuard SafariConverterLib](https://github.com/AdguardTeam/SafariConverterLib) (build-time only; GPL tool, not linked into Oriel).

| File | Source |
|------|--------|
| `oriel-base.json` | Common ad hosts |
| `oriel-ads-*.json` | EasyList + AdGuard Base |
| `oriel-privacy-*.json` | EasyPrivacy + AdGuard Tracking |
| `oriel-annoyances.json` | Fanboy Cookie + AdGuard Annoyances/Social |
| `oriel-youtube-ads.json` | Curated YouTube ad endpoints |
| `example-blocklist.json` | Fallback |

## Regenerate

```bash
git clone https://github.com/AdguardTeam/SafariConverterLib.git /tmp/SafariConverterLib
cd /tmp/SafariConverterLib && swift build -c release --product ConverterTool
export ORIEL_CONVERTER=/tmp/SafariConverterLib/.build/out/Products/Release/ConverterTool
cd /path/to/openoriel
python3 Scripts/build_content_blocker.py
```

Attribution: see repo `NOTICE`.
