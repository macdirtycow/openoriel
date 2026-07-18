# Oriel content blocker lists

Bundled under `Resources/ContentBlocker/`:

| File | Source |
|------|--------|
| `oriel-easylist.json` | Converted from [EasyList](https://easylist.to/) + [EasyPrivacy](https://easylist.to/) (`\|\|domain` network rules) |
| `oriel-youtube-ads.json` | Oriel YouTube ad endpoints + CSS hide + OAuth allowlist |
| `example-blocklist.json` | Tiny fallback if the main lists fail to compile |

## Regenerate

```bash
curl -sL -o /tmp/easylist.txt https://easylist.to/easylist/easylist.txt
curl -sL -o /tmp/easyprivacy.txt https://easylist.to/easylist/easyprivacy.txt
python3 Scripts/convert_easylist_to_webkit.py
```

EasyList/EasyPrivacy licence: https://easylist.to/pages/licence.html

## Limits

`WKContentRuleList` is not Brave’s adblock engine. In-stream YouTube ads that share first-party video CDNs may still appear; Oriel also injects a YouTube skip/hide script when Shields are on.
