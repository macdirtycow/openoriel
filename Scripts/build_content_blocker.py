#!/usr/bin/env python3
"""Build Oriel WKContentRuleList JSON using AdGuard SafariConverterLib.

Requires ConverterTool (GPL-3.0 build tool — not linked into Oriel):

  git clone https://github.com/AdguardTeam/SafariConverterLib.git /tmp/SafariConverterLib
  cd /tmp/SafariConverterLib && swift build -c release --product ConverterTool
  export ORIEL_CONVERTER=/tmp/SafariConverterLib/.build/out/Products/Release/ConverterTool

Then:

  python3 Scripts/build_content_blocker.py
"""

from __future__ import annotations

import json
import os
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "Resources" / "ContentBlocker"
MAX_RULES = 45_000
WORK = Path("/tmp/oriel-filters")

FILTER_URLS = {
    "easylist.txt": "https://easylist.to/easylist/easylist.txt",
    "easyprivacy.txt": "https://easylist.to/easylist/easyprivacy.txt",
    "fanboy-cookie.txt": "https://secure.fanboy.co.nz/fanboy-cookiemonster.txt",
    # Safari-oriented AdGuard snapshots (still Adblock/AdGuard syntax)
    "adguard-base.txt": "https://filters.adtidy.org/extension/safari/filters/2_optimized.txt",
    "adguard-tracking.txt": "https://filters.adtidy.org/extension/safari/filters/3_optimized.txt",
    "adguard-social.txt": "https://filters.adtidy.org/extension/safari/filters/4_optimized.txt",
    "adguard-annoyances.txt": "https://filters.adtidy.org/extension/safari/filters/14_optimized.txt",
}

GROUPS = {
    "ads": ["easylist.txt", "adguard-base.txt"],
    "privacy": ["easyprivacy.txt", "adguard-tracking.txt"],
    "annoyances": ["fanboy-cookie.txt", "adguard-annoyances.txt", "adguard-social.txt"],
}

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

# Paths that must never be blocked on YouTube first-party (homepage / player).
YOUTUBE_UNBLOCK = [
    r"^[^:]+://+([^:/]+\.)?youtube\.com\/get_video\?",
    r"^[^:]+://+([^:/]+\.)?youtube\.com\/get_video_info\?",
    r"^[^:]+://+([^:/]+\.)?www\.youtube\.com\/get_video\?",
]

YOUTUBE_RULES = [
    {"trigger": {"url-filter": r".*youtube\.com\/pagead\/"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": r".*youtube\.com\/ptracking"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": r".*youtube\.com\/api\/stats\/ads"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": r".*youtube\.com\/get_midroll_"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": r".*youtube\.com\/youtubei\/v1\/player\/ad_break"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": r".*youtube\.com\/pcs\/activeview"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": r".*ad\.youtube\.com"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": r".*googlevideo\.com\/.*[&?]oad="}, "action": {"type": "block"}},
    {"trigger": {"url-filter": r".*googlevideo\.com\/.*ctier=L"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": r".*doubleclick\.net"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": r".*googlesyndication\.com"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": r".*googleadservices\.com"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": r".*adservice\.google\."}, "action": {"type": "block"}},
    {
        "trigger": {"url-filter": r".*youtube\.com"},
        "action": {
            "type": "css-display-none",
            "selector": (
                "ytd-ad-slot-renderer, ytd-promoted-sparkles-web-renderer, "
                "ytd-in-feed-ad-layout-renderer, ytd-action-companion-ad-renderer, "
                "ytd-display-ad-renderer, ytd-banner-promo-renderer, "
                "ytd-player-legacy-desktop-watch-ads-renderer, "
                "#player-ads, #masthead-ad, "
                ".ytp-ad-module, .ytp-ad-player-overlay, .ytp-ad-overlay-container, "
                ".ytp-ad-action-interstitial, .ytp-ad-image-overlay, .video-ads"
            ),
        },
    },
]

BASE_HOSTS = [
    "doubleclick.net",
    "googlesyndication.com",
    "googleadservices.com",
    "amazon-adsystem.com",
    "adnxs.com",
    "adsrvr.org",
    "outbrain.com",
    "taboola.com",
    "criteo.com",
    "criteo.net",
    "pubmatic.com",
    "rubiconproject.com",
    "openx.net",
    "casalemedia.com",
    "bidswitch.net",
    "scorecardresearch.com",
    "quantserve.com",
    "moatads.com",
    "3lift.com",
    "teads.tv",
    "smartadserver.com",
    "media.net",
    "mgid.com",
    "revcontent.com",
    "carbonads.com",
    "buysellads.com",
    "propellerads.com",
    "popads.net",
    "exoclick.com",
    "juicyads.com",
    "googletagservices.com",
    "pagead2.googlesyndication.com",
]


def allowlist_rule() -> dict:
    return {
        "trigger": {"url-filter": ".*", "if-domain": ALLOWLIST_DOMAINS},
        "action": {"type": "ignore-previous-rules"},
    }


def download(name: str, url: str) -> Path:
    WORK.mkdir(parents=True, exist_ok=True)
    path = WORK / name
    if path.exists() and path.stat().st_size > 1000:
        print(f"Using cached {name}")
        return path
    print(f"Downloading {name}…")
    # curl is more reliable than urllib SSL on some Python installs
    subprocess.check_call(
        ["curl", "-fsSL", "-A", "OrielFilterBuild/1.0", "-o", str(path), url]
    )
    return path


def converter_path() -> Path:
    env = os.environ.get("ORIEL_CONVERTER")
    candidates = [
        Path(env) if env else None,
        Path("/tmp/SafariConverterLib/.build/out/Products/Release/ConverterTool"),
        Path("/tmp/SafariConverterLib/.build/release/ConverterTool"),
    ]
    for c in candidates:
        if c and c.is_file():
            return c
    raise SystemExit(
        "ConverterTool not found. Build AdGuard SafariConverterLib and set ORIEL_CONVERTER.\n"
        "See Scripts/build_content_blocker.py docstring."
    )


def convert_group(name: str, files: list[str], converter: Path) -> Path:
    combined = WORK / f"group-{name}.txt"
    parts = []
    for f in files:
        parts.append((WORK / f).read_text(encoding="utf-8", errors="ignore"))
    combined.write_text("\n".join(parts), encoding="utf-8")
    out = WORK / f"safari-{name}.json"
    cmd = [
        str(converter),
        "convert",
        "--safari-version",
        "17.0",
        "--advanced-blocking",
        "false",
        "--input-path",
        str(combined),
        "--safari-rules-json-path",
        str(out),
    ]
    print(f"Converting {name} ({combined.stat().st_size // 1024} KB)…")
    subprocess.check_call(cmd)
    return out


def should_drop(rule: dict) -> bool:
    if rule.get("action", {}).get("type") != "block":
        return False
    filt = rule.get("trigger", {}).get("url-filter", "")
    low = filt.lower()
    # Keep YouTube playback / homepage working
    if "youtube" in low and "get_video" in low:
        return True
    return False


def sanitize(rules: list[dict]) -> list[dict]:
    return [r for r in rules if not should_drop(r)]


def write_chunked(prefix: str, rules: list[dict]) -> None:
    for old in OUT_DIR.glob(f"{prefix}*.json"):
        old.unlink()
    if not rules:
        return
    room = MAX_RULES - 1
    total = (len(rules) + room - 1) // room
    for i in range(0, len(rules), room):
        chunk = list(rules[i : i + room])
        chunk.append(allowlist_rule())
        idx = i // room
        name = prefix if total == 1 else f"{prefix}-{idx + 1}"
        path = OUT_DIR / f"{name}.json"
        path.write_text(json.dumps(chunk, separators=(",", ":")), encoding="utf-8")
        print(f"  Wrote {path.name}: {len(chunk)} rules ({path.stat().st_size // 1024} KB)")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    converter = converter_path()
    print("Using", converter)

    for name, url in FILTER_URLS.items():
        download(name, url)

    # Clear previous generated lists (keep example-blocklist.json)
    for pattern in (
        "oriel-ads*.json",
        "oriel-privacy*.json",
        "oriel-annoyances*.json",
        "oriel-easylist*.json",
        "oriel-easyprivacy*.json",
        "oriel-cosmetic*.json",
        "oriel-base*.json",
        "oriel-youtube-ads*.json",
    ):
        for old in OUT_DIR.glob(pattern):
            old.unlink()

    base = [
        {"trigger": {"url-filter": ".*" + re.escape(h)}, "action": {"type": "block"}}
        for h in BASE_HOSTS
    ]
    write_chunked("oriel-base", base)

    for group, files in GROUPS.items():
        path = convert_group(group, files, converter)
        rules = sanitize(json.loads(path.read_text(encoding="utf-8")))
        print(f"{group}: {len(rules)} rules after sanitize")
        write_chunked(f"oriel-{group}", rules)

    yt = list(YOUTUBE_RULES) + [allowlist_rule()]
    (OUT_DIR / "oriel-youtube-ads.json").write_text(
        json.dumps(yt, separators=(",", ":")), encoding="utf-8"
    )
    print(f"Wrote oriel-youtube-ads.json: {len(yt)} rules")
    print("Done.")


if __name__ == "__main__":
    main()
