#!/usr/bin/env python3
"""Convert EasyList / EasyPrivacy into WKContentRuleList JSON for Oriel.

Produces multiple chunks (WebKit max 50k rules per list):
  oriel-easylist-1.json / oriel-easylist-2.json
  oriel-easyprivacy-1.json / oriel-easyprivacy-2.json
  oriel-cosmetic.json
  oriel-youtube-ads.json

Each chunk ends with an OAuth/login allowlist (ignore-previous-rules only
applies within the same compiled list).
"""

from __future__ import annotations

import json
import re
from pathlib import Path

MAX_RULES_PER_FILE = 45_000
OUT_DIR = Path(__file__).resolve().parents[1] / "Resources" / "ContentBlocker"

RESOURCE_MAP = {
    "script": "script",
    "image": "image",
    "stylesheet": "style-sheet",
    "object": "media",
    "xmlhttprequest": "raw",
    "ping": "raw",
    "media": "media",
    "font": "font",
    "subdocument": "document",
    "other": "raw",
    "fetch": "raw",
    "websocket": "raw",
}

DOMAIN_RULE = re.compile(r"^\|\|([a-z0-9._*-]+)(?:\^|\/|\||$)(.*)$", re.I)
COSMETIC = re.compile(r"^([^#]*)##(.+)$")
COSMETIC_EXC = re.compile(r"^([^#]*)#@#(.+)$")
# Simple path / keyword network rules: /ads.js$script
PATH_CONTAINS = re.compile(r"^\/([a-z0-9_\-./%]{3,80})\/?(?:\$.*)?$", re.I)

ALLOWLIST_DOMAINS = [
    "*accounts.google.com",
    "*myaccount.google.com",
    "*accounts.youtube.com",
    "*oauth2.googleapis.com",
    "*appleid.apple.com",
    "*login.live.com",
    "*login.microsoftonline.com",
    "*github.com",
]


def allowlist_rule() -> dict:
    return {
        "trigger": {"url-filter": ".*", "if-domain": ALLOWLIST_DOMAINS},
        "action": {"type": "ignore-previous-rules"},
    }


def escape_regex(s: str) -> str:
    return re.escape(s).replace(r"\*", ".*")


def parse_options(opts: str) -> dict:
    result = {
        "third_party": None,
        "resource_types": [],
        "domains": [],
        "unless_domains": [],
        "skip": False,
    }
    if not opts:
        return result
    for part in opts.split(","):
        part = part.strip()
        if not part:
            continue
        low = part.lower()
        if low in ("third-party", "3p"):
            result["third_party"] = True
        elif low in ("~third-party", "first-party", "1p"):
            result["third_party"] = False
        elif low.startswith("domain="):
            for d in part.split("=", 1)[1].split("|"):
                d = d.strip().lower()
                if not d:
                    continue
                if d.startswith("~"):
                    result["unless_domains"].append(d[1:])
                else:
                    result["domains"].append(d)
        elif low.startswith("~"):
            continue
        elif low in RESOURCE_MAP:
            result["resource_types"].append(RESOURCE_MAP[low])
        elif low in (
            "popup",
            "document",
            "elemhide",
            "generichide",
            "genericblock",
            "csp",
            "rewrite",
            "mp4",
            "empty",
            "important",
        ):
            # Unsupported or unsafe for WK network block path
            if low in ("popup", "document", "csp", "rewrite", "mp4", "empty"):
                result["skip"] = True
        elif low.startswith("rewrite=") or low.startswith("csp="):
            result["skip"] = True
    return result


def domain_to_filter(domain: str) -> str | None:
    domain = domain.strip().lower()
    if not domain or domain.startswith("/") or "=" in domain:
        return None
    if domain.count("*") > 2:
        return None
    domain = domain.lstrip(".")
    if domain.startswith("*."):
        domain = domain[2:]
    if "*" in domain:
        if domain.startswith("*") or domain.endswith("*"):
            domain = domain.strip("*")
        else:
            return None
    if not domain or "." not in domain:
        return None
    if len(domain) > 120:
        return None
    return f".*{escape_regex(domain)}"


def make_block(url_filter: str, options: dict) -> dict | None:
    if options.get("skip"):
        return None
    trigger: dict = {"url-filter": url_filter}
    if options.get("third_party") is True:
        trigger["load-type"] = ["third-party"]
    elif options.get("third_party") is False:
        trigger["load-type"] = ["first-party"]
    if options.get("resource_types"):
        trigger["resource-type"] = sorted(set(options["resource_types"]))
    if options.get("domains"):
        trigger["if-domain"] = [
            f"*{d}" if not d.startswith("*") else d for d in options["domains"][:40]
        ]
    if options.get("unless_domains"):
        trigger["unless-domain"] = [
            f"*{d}" if not d.startswith("*") else d for d in options["unless_domains"][:40]
        ]
    return {"trigger": trigger, "action": {"type": "block"}}


def make_ignore(url_filter: str, options: dict) -> dict:
    trigger: dict = {"url-filter": url_filter}
    if options.get("domains"):
        trigger["if-domain"] = [
            f"*{d}" if not d.startswith("*") else d for d in options["domains"][:40]
        ]
    return {"trigger": trigger, "action": {"type": "ignore-previous-rules"}}


def convert_network_line(line: str) -> list[dict]:
    line = line.strip()
    if not line or line.startswith("!") or line.startswith("["):
        return []
    if "##" in line or "#@#" in line or "#?#" in line or "#$#" in line or "#%#" in line:
        return []

    if line.startswith("@@"):
        raw = line[2:]
        opts = ""
        if "$" in raw:
            raw, opts = raw.split("$", 1)
        options = parse_options(opts)
        if raw.startswith("||"):
            m = DOMAIN_RULE.match(raw)
            if not m:
                return []
            filt = domain_to_filter(m.group(1))
            if not filt:
                return []
            return [make_ignore(filt, options)]
        return []

    opts = ""
    body = line
    if "$" in line:
        body, opts = line.split("$", 1)
    options = parse_options(opts)

    if body.startswith("||"):
        m = DOMAIN_RULE.match(body)
        if not m:
            return []
        domain = m.group(1)
        rest = m.group(2) or ""
        filt = domain_to_filter(domain)
        if not filt:
            return []
        if rest.startswith("/") and len(rest) > 1 and not rest.startswith("/*"):
            path = rest.split("$")[0]
            if all(c.isalnum() or c in "/._-%" for c in path[:80]):
                filt = filt + escape_regex(path[:80])
        rule = make_block(filt, options)
        return [rule] if rule else []

    # Anchored URL prefix |http://… or |https://…
    if body.startswith("|http://") or body.startswith("|https://"):
        raw = body[1:]
        # Strip trailing anchors
        raw = raw.rstrip("|").rstrip("^")
        if len(raw) < 12 or len(raw) > 180:
            return []
        if any(c in raw for c in "*?()+[]{}"):
            return []
        filt = escape_regex(raw)
        rule = make_block(filt, options)
        return [rule] if rule else []

    # Path / keyword rules that look like ads (reduces false positives)
    if body.startswith("/") and body.count("/") >= 2:
        m = PATH_CONTAINS.match(body.split("$")[0] + ("$" + opts if opts else ""))
        # Accept /ads, /ad/, /banner, /track, /pixel style paths
        core = body.split("$")[0].strip("/")
        low = core.lower()
        keywords = (
            "ad",
            "ads",
            "advert",
            "banner",
            "sponsor",
            "tracking",
            "tracker",
            "pixel",
            "analytics",
            "doubleclick",
            "pagead",
            "popunder",
            "popup",
            "prebid",
            "taboola",
            "outbrain",
        )
        if any(k in low for k in keywords) and 3 <= len(core) <= 60:
            if all(c.isalnum() or c in "/._-%" for c in core):
                filt = f".*{escape_regex('/' + core)}"
                # Prefer third-party for generic path hits
                if options.get("third_party") is None:
                    options = dict(options)
                    options["third_party"] = True
                rule = make_block(filt, options)
                return [rule] if rule else []

    return []


def sanitize_selector(sel: str) -> str | None:
    sel = sel.strip()
    if not sel or len(sel) > 300:
        return None
    # Skip procedural / scriptlet-like cosmetics
    bad = (":has(", ":xpath(", "+js(", ":style(", "abort-", "trusted-")
    low = sel.lower()
    if any(b in low for b in bad):
        return None
    if any(c in sel for c in ("{", "}", '"', "\\")):
        return None
    return sel


def convert_cosmetic_line(line: str) -> list[tuple[tuple[str, ...], str]]:
    """Return list of (domains_tuple, selector). Empty domains = generic."""
    line = line.strip()
    if not line or line.startswith("!") or line.startswith("["):
        return []
    if "#@#" in line:
        return []  # exceptions not expressible cleanly in WK
    m = COSMETIC.match(line)
    if not m:
        return []
    domains_raw, selector = m.group(1), m.group(2)
    sel = sanitize_selector(selector)
    if not sel:
        return []
    if not domains_raw:
        return [(tuple(), sel)]
    domains: list[str] = []
    for d in domains_raw.split(","):
        d = d.strip().lower()
        if not d or d.startswith("~"):
            continue
        if not re.match(r"^[a-z0-9.-]+$", d):
            continue
        domains.append(d)
    if not domains:
        return []
    return [(tuple(domains[:20]), sel)]


def batch_cosmetics(items: list[tuple[tuple[str, ...], str]], batch_size: int = 25) -> list[dict]:
    """Group selectors that share the same domain set."""
    from collections import defaultdict

    groups: dict[tuple[str, ...], list[str]] = defaultdict(list)
    seen: set[str] = set()
    for domains, sel in items:
        key = f"{domains}::{sel}"
        if key in seen:
            continue
        seen.add(key)
        groups[domains].append(sel)

    rules: list[dict] = []
    for domains, sels in groups.items():
        for i in range(0, len(sels), batch_size):
            chunk = sels[i : i + batch_size]
            trigger: dict = {"url-filter": ".*"}
            if domains:
                trigger["if-domain"] = [f"*{d}" if not d.startswith("*") else d for d in domains]
            rules.append(
                {
                    "trigger": trigger,
                    "action": {"type": "css-display-none", "selector": ", ".join(chunk)},
                }
            )
    return rules


YOUTUBE_RULES = [
    {"trigger": {"url-filter": ".*youtube\\.com\\/pagead\\/"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*youtube\\.com\\/ptracking"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*youtube\\.com\\/api\\/stats\\/ads"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*youtube\\.com\\/api\\/stats\\/atr"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*youtube\\.com\\/get_midroll_"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*youtube\\.com\\/youtubei\\/v1\\/log_event"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*youtube\\.com\\/youtubei\\/v1\\/att\\/get"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*youtube\\.com\\/youtubei\\/v1\\/player\\/ad_break"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*s\\.youtube\\.com\\/api\\/stats\\/"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*youtube\\.com\\/pcs\\/"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*youtube\\.com\\/pagead\\/"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*youtube\\.com\\/ad_"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*googlevideo\\.com\\/.*&oad="}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*googlevideo\\.com\\/.*ctier=L"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*googlevideo\\.com\\/.*&alr=yes"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*doubleclick\\.net"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*googleads\\.g\\.doubleclick\\.net"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*pagead2\\.googlesyndication\\.com"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*googlesyndication\\.com"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*googleadservices\\.com"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*ad\\.youtube\\.com"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*adservice\\.google\\."}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*youtube\\.com\\/ptracking"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*youtube\\.com\\/api\\/stats\\/qoe"}, "action": {"type": "block"}},
    {
        "trigger": {"url-filter": ".*youtube\\.com"},
        "action": {
            "type": "css-display-none",
            "selector": (
                ".ytp-ad-module, .ytp-ad-player-overlay, .ytp-ad-overlay-container, "
                ".ytp-ad-action-interstitial, .ytp-ad-preview-container, .video-ads, "
                "ytd-ad-slot-renderer, ytd-promoted-sparkles-web-renderer, "
                "ytd-player-legacy-desktop-watch-ads-renderer, ytd-in-feed-ad-layout-renderer, "
                "ytd-action-companion-ad-renderer, ytd-display-ad-renderer, "
                "ytd-banner-promo-renderer, ytd-statement-banner-renderer, "
                "ytd-promoted-video-renderer, #player-ads, #masthead-ad, #offer-module"
            ),
        },
    },
    {
        "trigger": {"url-filter": ".*youtube-nocookie\\.com"},
        "action": {
            "type": "css-display-none",
            "selector": (
                ".ytp-ad-module, .ytp-ad-player-overlay, .video-ads, "
                ".ytp-ad-overlay-container, .ytp-ad-action-interstitial"
            ),
        },
    },
]


def convert_network_file(path: Path) -> list[dict]:
    rules: list[dict] = []
    seen: set[str] = set()
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        for rule in convert_network_line(line):
            key = json.dumps(rule, sort_keys=True)
            if key in seen:
                continue
            seen.add(key)
            rules.append(rule)
    return rules


def convert_cosmetics(paths: list[Path], max_rules: int = 40_000) -> list[dict]:
    items: list[tuple[tuple[str, ...], str]] = []
    for path in paths:
        for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
            items.extend(convert_cosmetic_line(line))
    # Prefer generic (empty domain) first — highest coverage per rule after batching
    items.sort(key=lambda x: (0 if not x[0] else 1, x[0], x[1]))
    rules = batch_cosmetics(items)
    return rules[:max_rules]


def write_chunked(prefix: str, rules: list[dict]) -> list[Path]:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    # Clear old numbered files for this prefix
    for old in OUT_DIR.glob(f"{prefix}*.json"):
        old.unlink()

    paths: list[Path] = []
    if not rules:
        return paths

    # Reserve one slot for allowlist at end of each chunk
    room = MAX_RULES_PER_FILE - 1
    total_chunks = (len(rules) + room - 1) // room
    for i in range(0, len(rules), room):
        chunk = list(rules[i : i + room])
        chunk.append(allowlist_rule())
        idx = i // room
        name = prefix if total_chunks == 1 else f"{prefix}-{idx + 1}"
        out = OUT_DIR / f"{name}.json"
        out.write_text(json.dumps(chunk, separators=(",", ":")), encoding="utf-8")
        paths.append(out)
        print(f"Wrote {out.name}: {len(chunk)} rules ({out.stat().st_size // 1024} KB)")
    return paths


def main() -> None:
    easylist = Path("/tmp/easylist.txt")
    easyprivacy = Path("/tmp/easyprivacy.txt")
    if not easylist.exists() or not easyprivacy.exists():
        raise SystemExit("Download EasyList + EasyPrivacy to /tmp first (see README).")

    # Remove previous generated lists (keep example-blocklist.json)
    for pattern in (
        "oriel-easylist*.json",
        "oriel-easyprivacy*.json",
        "oriel-cosmetic*.json",
        "oriel-youtube-ads*.json",
    ):
        for old in OUT_DIR.glob(pattern):
            old.unlink()

    el = convert_network_file(easylist)
    ep = convert_network_file(easyprivacy)
    print(f"EasyList network: {len(el)}")
    print(f"EasyPrivacy network: {len(ep)}")

    write_chunked("oriel-easylist", el)
    write_chunked("oriel-easyprivacy", ep)

    cosmetics = convert_cosmetics([easylist, easyprivacy], max_rules=40_000)
    print(f"Cosmetic rules (batched): {len(cosmetics)}")
    write_chunked("oriel-cosmetic", cosmetics)

    yt_out = OUT_DIR / "oriel-youtube-ads.json"
    yt_rules = list(YOUTUBE_RULES) + [allowlist_rule()]
    yt_out.write_text(json.dumps(yt_rules, separators=(",", ":")), encoding="utf-8")
    print(f"Wrote {yt_out.name}: {len(yt_rules)} rules ({yt_out.stat().st_size // 1024} KB)")
    print("Done.")


if __name__ == "__main__":
    main()
