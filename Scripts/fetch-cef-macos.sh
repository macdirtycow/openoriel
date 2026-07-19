#!/usr/bin/env bash
# Download Chromium Embedded Framework (CEF) for Mac Oriel Native builds.
# This does NOT vendor CEF into git — it installs under ~/Library/Application Support/Oriel/CEF/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${ORIEL_CEF_DIR:-$HOME/Library/Application Support/Oriel/CEF}"
# CEF builds are large; pin a known macOS arm64/universal branch build when available.
# Users can override: ORIEL_CEF_URL=... bash Scripts/fetch-cef-macos.sh
CEF_URL="${ORIEL_CEF_URL:-}"

echo "Oriel CEF fetch"
echo "  dest: $DEST"

mkdir -p "$DEST"

if [[ -z "$CEF_URL" ]]; then
  cat <<'EOF'
No ORIEL_CEF_URL set.

To enable embedded Chromium Native:
  1. Download a macOS CEF Standard Distribution from https://cef-builds.spotifycdn.com/index.html
  2. Export ORIEL_CEF_URL to that .tar.bz2 (or place the framework manually)
  3. Re-run: bash Scripts/fetch-cef-macos.sh

Or copy "Chromium Embedded Framework.framework" into:
  ~/Library/Application Support/Oriel/CEF/

Until CEF is present, Oriel Mac Native mode uses managed system Chromium app-windows
(real Blink process via Chrome/Brave/Edge/Arc).
EOF
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
ARCHIVE="$TMP/cef.tar.bz2"
echo "Downloading $CEF_URL …"
curl -L --fail --progress-bar "$CEF_URL" -o "$ARCHIVE"
echo "Extracting…"
tar -xjf "$ARCHIVE" -C "$TMP"
FRAMEWORK="$(find "$TMP" -type d -name 'Chromium Embedded Framework.framework' | head -1 || true)"
if [[ -z "$FRAMEWORK" ]]; then
  echo "error: Chromium Embedded Framework.framework not found in archive" >&2
  exit 1
fi
rm -rf "$DEST/Chromium Embedded Framework.framework"
cp -R "$FRAMEWORK" "$DEST/"
echo "Installed: $DEST/Chromium Embedded Framework.framework"
echo "Restart Oriel — Chromium Native status should become Available."
