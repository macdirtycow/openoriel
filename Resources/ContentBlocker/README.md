# Content blocker lists

| File | Source |
|------|--------|
| `oriel-base.json` | Common ad/tracker hosts |
| `oriel-easylist-*.json` | [EasyList](https://easylist.to/) network rules |
| `oriel-easyprivacy-*.json` | [EasyPrivacy](https://easylist.to/) network rules |
| `oriel-cosmetic.json` | Element hiding (`##`) as `css-display-none` |
| `oriel-youtube-ads.json` | YouTube ad endpoints + CSS hide |
| `example-blocklist.json` | Fallback |

YouTube, `googleapis`, `gstatic`, and related first-party hosts are not blocked as bare domains. Each list ends with an OAuth/login allowlist (`ignore-previous-rules` is per list).

## Regenerate

```bash
curl -fsSL -o /tmp/easylist.txt https://easylist.to/easylist/easylist.txt
curl -fsSL -o /tmp/easyprivacy.txt https://easylist.to/easylist/easyprivacy.txt
python3 Scripts/convert_easylist_to_webkit.py
```

See `NOTICE` and https://easylist.to/pages/licence.html for attribution.
