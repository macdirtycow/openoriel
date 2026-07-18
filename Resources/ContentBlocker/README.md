# Content blocker lists

| File | Role |
|------|------|
| `oriel-easylist.json` | EasyList + EasyPrivacy → WebKit network rules |
| `oriel-youtube-ads.json` | YouTube endpoints, CSS hide, OAuth allowlist |
| `example-blocklist.json` | Tiny fallback if primary lists fail |

## Regenerate

```bash
curl -fsSL -o /tmp/easylist.txt https://easylist.to/easylist/easylist.txt
curl -fsSL -o /tmp/easyprivacy.txt https://easylist.to/easylist/easyprivacy.txt
python3 Scripts/convert_easylist_to_webkit.py
```

Licence and attribution: see repo root `NOTICE` and https://easylist.to/pages/licence.html

`WKContentRuleList` is not Brave’s engine. Some first-party YouTube streams can still play; Oriel also injects a skip/hide script when Shields are on.
