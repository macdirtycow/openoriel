# Privacy

Oriel’s privacy features run on Apple WebKit. This page is the source of truth for what we claim in UI and marketing.

## What Oriel does

| Protection | Mechanism |
|------------|-----------|
| Tracker / ad blocking | Bundled `WKContentRuleList` rules (EasyList + EasyPrivacy network + cosmetic hiding + YouTube rules) |
| YouTube player ads | Network/CSS rules plus an injected skip/hide script when Shields are on |
| HTTPS upgrade | Prefer `https` when heuristics allow |
| Third-party cookies | Configurable via WebKit data-store preferences (OS-dependent) |
| Clear site data | `WKWebsiteDataStore` removal APIs |
| Private browsing | Non-persistent data store; not written to history |
| Per-site Shields | Local overrides applied when configuring / updating the web view |
| Site permissions | Camera, mic, location via WebKit + system prompts |

## What Oriel does not control

| Limitation | Why |
|------------|-----|
| Network-wide firewall / VPN | Traffic goes through WebKit inside the app sandbox |
| Complete fingerprint defense | Pages can still use WebKit-exposed APIs |
| Guaranteed tracker kill | Dynamic, first-party, and CNAME tricks can evade static rules |
| Full Brave / uBlock scriptlet parity | `WKContentRuleList` is not those engines |
| Every YouTube in-stream ad | Some ads share first-party video CDNs |
| Custom TLS / pinning for all sites | System certificate validation stays on |
| Chrome Web Store install APIs | macOS install uses CRX download + `WKWebExtension` |
| Perfect “incognito” on the wire | Destinations and networks still see traffic |

## Copy rules

Prefer concrete language (“blocked requests matching your filter lists”, “upgraded to HTTPS when possible”).

Avoid “100% private”, “invisible to trackers”, “military-grade”, or anything that implies a custom engine or VPN without shipping one.
