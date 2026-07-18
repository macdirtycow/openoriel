# Privacy

Shields and related features use Apple WebKit APIs.

## Implemented

| Feature | Mechanism |
|---------|-----------|
| Tracker / ad blocking | `WKContentRuleList` from EasyList, EasyPrivacy, AdGuard, and Fanboy lists (via SafariConverterLib at build time) |
| YouTube ads | Network/CSS rules + skip script when Shields are on |
| HTTPS upgrade | Prefer `https` when heuristics allow |
| Third-party cookies | WebKit data-store preferences (OS-dependent) |
| Clear site data | `WKWebsiteDataStore` removal |
| Private browsing | Non-persistent data store; not written to history |
| Per-site Shields | Local overrides on the web view |
| Site permissions | Camera, mic, location via WebKit + system prompts |

## Limits

| Limit | Reason |
|-------|--------|
| No system-wide firewall / VPN | Traffic stays inside the app sandbox via WebKit |
| Incomplete fingerprint defense | Pages can use WebKit-exposed APIs |
| Incomplete tracker blocking | Dynamic / first-party / CNAME evasion |
| Not Brave / uBlock | `WKContentRuleList` is a different engine |
| Some YouTube in-stream ads | Shared first-party video CDNs |
| No custom TLS pinning | System certificate validation |
| No Chrome install APIs | CRX download + `WKWebExtension` on macOS |
