#!/usr/bin/env python3
"""Convert EasyList / EasyPrivacy to Safari WKContentRuleList JSON chunks for Oriel."""

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
}

DOMAIN_RULE = re.compile(r"^\|\|([a-z0-9._*-]+)(?:\^|\/|\||$)(.*)$", re.I)
PATH_RULE = re.compile(r"^\/(.+)\/$")


def escape_regex(s: str) -> str:
    return re.escape(s).replace(r"\*", ".*")


def parse_options(opts: str) -> dict:
    result = {
        "third_party": None,
        "resource_types": [],
        "domains": [],
        "unless_domains": [],
        "invert": False,
    }
    if not opts:
        return result
    for part in opts.split(","):
        part = part.strip()
        if not part:
            continue
        low = part.lower()
        if low == "third-party" or low == "3p":
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
            key = low[1:]
            if key in RESOURCE_MAP:
                pass  # skip negated resource types for simplicity
        elif low in RESOURCE_MAP:
            result["resource_types"].append(RESOURCE_MAP[low])
        elif low in ("popup", "document", "elemhide", "generichide", "genericblock"):
            result["invert"] = True  # skip unsupported for network block path
    return result


def domain_to_filter(domain: str) -> str | None:
    domain = domain.strip().lower()
    if not domain or domain.startswith("/") or "=" in domain:
        return None
    # Skip overly broad wildcards
    if domain.count("*") > 2:
        return None
    # ||*.example.com → .*example\.com
    domain = domain.lstrip(".")
    if domain.startswith("*."):
        domain = domain[2:]
    if "*" in domain:
        # convert foo.*.bar carefully — skip complex
        if domain.startswith("*") or domain.endswith("*"):
            domain = domain.strip("*")
        else:
            return None
    if not domain or "." not in domain:
        return None
    return f".*{escape_regex(domain)}"


def make_block(url_filter: str, options: dict) -> dict | None:
    if options.get("invert"):
        return None
    trigger: dict = {"url-filter": url_filter}
    if options.get("third_party") is True:
        trigger["load-type"] = ["third-party"]
    elif options.get("third_party") is False:
        trigger["load-type"] = ["first-party"]
    if options.get("resource_types"):
        # WebKit wants unique resource types
        trigger["resource-type"] = sorted(set(options["resource_types"]))
    if options.get("domains"):
        trigger["if-domain"] = [f"*{d}" if not d.startswith("*") else d for d in options["domains"][:50]]
    if options.get("unless_domains"):
        trigger["unless-domain"] = [f"*{d}" if not d.startswith("*") else d for d in options["unless_domains"][:50]]
    return {"trigger": trigger, "action": {"type": "block"}}


def make_ignore(url_filter: str, options: dict) -> dict:
    trigger: dict = {"url-filter": url_filter}
    if options.get("domains"):
        trigger["if-domain"] = [f"*{d}" if not d.startswith("*") else d for d in options["domains"][:50]]
    return {"trigger": trigger, "action": {"type": "ignore-previous-rules"}}


def convert_line(line: str) -> list[dict]:
    line = line.strip()
    if not line or line.startswith("!") or line.startswith("["):
        return []
    # Skip element hiding / scriptlets / snippets for bulk (handled in curated YouTube file)
    if "##" in line or "#@#" in line or "#?#" in line or "#$#" in line:
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
        # Optional path after domain
        if rest.startswith("/") and len(rest) > 1 and not rest.startswith("/*"):
            path = rest.split("$")[0]
            # keep simple paths only
            if all(c.isalnum() or c in "/._-%" for c in path[:80]):
                filt = filt + escape_regex(path[:80])
        rule = make_block(filt, options)
        return [rule] if rule else []

    # Generic path contains: skip — too noisy / false positives for WebKit
    return []


YOUTUBE_RULES = [
    # Network endpoints used for YT ads / tracking
    {"trigger": {"url-filter": ".*youtube\\.com\\/pagead\\/"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*youtube\\.com\\/ptracking"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*youtube\\.com\\/api\\/stats\\/ads"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*youtube\\.com\\/api\\/stats\\/qoe"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*youtube\\.com\\/get_midroll_"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*youtube\\.com\\/youtubei\\/v1\\/log_event"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*youtube\\.com\\/youtubei\\/v1\\/att\\/get"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*s\\.youtube\\.com\\/api\\/stats\\/"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*youtube\\.com\\/pcs\\/activeview"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*youtube\\.com\\/pagead\\/adview"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*googlevideo\\.com\\/.*&oad="}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*googlevideo\\.com\\/.*ctier=L"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*doubleclick\\.net"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*googleads\\.g\\.doubleclick\\.net"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*pagead2\\.googlesyndication\\.com"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*ad\\.youtube\\.com"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*adservice\\.google\\."}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*www\\.youtube\\.com\\/ptracking"}, "action": {"type": "block"}},
    # Hide common ad UI chrome on YouTube
    {
        "trigger": {"url-filter": ".*youtube\\.com"},
        "action": {
            "type": "css-display-none",
            "selector": ".ytp-ad-module, .ytp-ad-player-overlay, .ytp-ad-overlay-container, .video-ads, ytd-ad-slot-renderer, ytd-promoted-sparkles-web-renderer, ytd-player-legacy-desktop-watch-ads-renderer, #player-ads, .ytd-display-ad-renderer, ytd-in-feed-ad-layout-renderer, ytd-ad-slot-renderer, .ytp-ad-action-interstitial",
        },
    },
    {
        "trigger": {"url-filter": ".*youtube-nocookie\\.com"},
        "action": {
            "type": "css-display-none",
            "selector": ".ytp-ad-module, .ytp-ad-player-overlay, .video-ads, .ytp-ad-overlay-container",
        },
    },
]

ALLOWLIST = {
    "trigger": {
        "url-filter": ".*",
        "if-domain": [
            "*accounts.google.com",
            "*myaccount.google.com",
            "*accounts.youtube.com",
            "*oauth2.googleapis.com",
            "*appleid.apple.com",
            "*login.live.com",
            "*login.microsoftonline.com",
            "*github.com",
            "www.google.com",
            "google.com",
        ],
    },
    "action": {"type": "ignore-previous-rules"},
}


def convert_file(path: Path) -> list[dict]:
    rules: list[dict] = []
    seen: set[str] = set()
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        for rule in convert_line(line):
            key = json.dumps(rule, sort_keys=True)
            if key in seen:
                continue
            seen.add(key)
            rules.append(rule)
    return rules


def write_chunks(name: str, rules: list[dict]) -> list[Path]:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    paths: list[Path] = []
    if not rules:
        return paths
    for i in range(0, len(rules), MAX_RULES_PER_FILE):
        chunk = rules[i : i + MAX_RULES_PER_FILE]
        # Allowlist must be last in the last chunk only
        idx = i // MAX_RULES_PER_FILE
        suffix = "" if idx == 0 and len(rules) <= MAX_RULES_PER_FILE else f"-{idx + 1}"
        out = OUT_DIR / f"{name}{suffix}.json"
        out.write_text(json.dumps(chunk, separators=(",", ":")), encoding="utf-8")
        paths.append(out)
        print(f"Wrote {out.name}: {len(chunk)} rules ({out.stat().st_size // 1024} KB)")
    return paths


def main() -> None:
    easylist = Path("/tmp/easylist.txt")
    easyprivacy = Path("/tmp/easyprivacy.txt")
    network = convert_file(easylist) + convert_file(easyprivacy)
    # Prefer domain blocks first by sorting shorter filters first? keep order.
    print(f"Converted network rules: {len(network)}")

    youtube = list(YOUTUBE_RULES)
    # Put YouTube + allowlist in a dedicated small high-priority file loaded last
    youtube_and_allow = youtube + [ALLOWLIST]
    write_chunks("oriel-youtube-ads", youtube_and_allow)

    # Cap EasyList-derived rules for reliable WK compile times / size.
    capped = network[:40_000]
    write_chunks("oriel-easylist", capped)

    # Remove obsolete example list from being the only list (keep as tiny fallback name unused)
    print("Done.")


if __name__ == "__main__":
    main()
