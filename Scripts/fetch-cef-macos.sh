#!/usr/bin/env bash
# Download Chromium Embedded Framework (CEF) Standard Distribution for Mac Oriel Engine.
# Installs under ~/Library/Application Support/Oriel/CEF/ (not vendored into git).
#
# Usage:
#   bash Scripts/fetch-cef-macos.sh
#   ORIEL_CEF_ARCH=macosx64 bash Scripts/fetch-cef-macos.sh   # Intel override
#   ORIEL_CEF_URL=https://...tar.bz2 bash Scripts/fetch-cef-macos.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${ORIEL_CEF_DIR:-$HOME/Library/Application Support/Oriel/CEF}"
VENDOR_LINK="$ROOT/Vendor/CEF"
CDN="https://cef-builds.spotifycdn.com"

# Pinned Standard builds (Chromium 144). Override with ORIEL_CEF_URL.
PIN_VERSION="144.0.30+g9e70dde+chromium-144.0.7559.257"
PIN_ARM64_SHA1="52f7336a55a0bf54563675b81704e8d1d05bc14f"
PIN_X64_SHA1="20ef471026c7bb712ead354c0d61a5608fa60d7c"

arch_default() {
  local m
  m="$(uname -m)"
  case "$m" in
    arm64|aarch64) echo "macosarm64" ;;
    *) echo "macosx64" ;;
  esac
}

ARCH="${ORIEL_CEF_ARCH:-$(arch_default)}"
case "$ARCH" in
  macosarm64) PIN_SHA1="$PIN_ARM64_SHA1" ;;
  macosx64) PIN_SHA1="$PIN_X64_SHA1" ;;
  *)
    echo "error: unsupported ORIEL_CEF_ARCH=$ARCH (use macosarm64 or macosx64)" >&2
    exit 1
    ;;
esac

ARCHIVE_NAME="cef_binary_${PIN_VERSION}_${ARCH}.tar.bz2"
# Spotify CDN requires '+' percent-encoded in the path.
ENCODED_NAME="${ARCHIVE_NAME//+/%2B}"
DEFAULT_URL="${CDN}/${ENCODED_NAME}"
CEF_URL="${ORIEL_CEF_URL:-$DEFAULT_URL}"

echo "Oriel Engine CEF fetch"
echo "  arch: $ARCH"
echo "  ver:  $PIN_VERSION"
echo "  dest: $DEST"
echo "  url:  $CEF_URL"

mkdir -p "$DEST"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
ARCHIVE="$TMP/cef.tar.bz2"

echo "Downloading…"
curl -L --fail --progress-bar "$CEF_URL" -o "$ARCHIVE"

if [[ -z "${ORIEL_CEF_URL:-}" ]]; then
  echo "Verifying SHA1…"
  actual="$(shasum -a 1 "$ARCHIVE" | awk '{print $1}')"
  if [[ "$actual" != "$PIN_SHA1" ]]; then
    echo "error: SHA1 mismatch (got $actual, expected $PIN_SHA1)" >&2
    exit 1
  fi
fi

echo "Extracting…"
tar -xjf "$ARCHIVE" -C "$TMP"
EXTRACT_ROOT="$(find "$TMP" -maxdepth 1 -type d -name 'cef_binary_*' | head -1 || true)"
if [[ -z "$EXTRACT_ROOT" || ! -d "$EXTRACT_ROOT/Release/Chromium Embedded Framework.framework" ]]; then
  echo "error: CEF Standard distribution layout not found (expected Release/Chromium Embedded Framework.framework)" >&2
  exit 1
fi

echo "Installing (Release tree; skipping Debug + tests)…"
rm -rf "$DEST"
mkdir -p "$DEST"
# Keep cmake + libcef_dll + include + Release so we can build libcef_dll_wrapper.
# Omit Debug (huge) and tests (we ship Oriel's own Helper source).
rsync -a \
  --exclude 'Debug/' \
  --exclude 'tests/' \
  --exclude '.git/' \
  "$EXTRACT_ROOT/" "$DEST/"

# Convenience: flat framework path for runtime probes + docs.
rm -f "$DEST/Chromium Embedded Framework.framework"
ln -s "Release/Chromium Embedded Framework.framework" "$DEST/Chromium Embedded Framework.framework"

# Do NOT write a file named VERSION/version — on macOS (case-insensitive)
# it shadows the C++ standard header <version> when -I$DEST is used.
mkdir -p "$DEST/oriel-meta"
printf '%s\n' "$PIN_VERSION" > "$DEST/oriel-meta/CEF_VERSION"
printf '%s\n' "$ARCH" > "$DEST/oriel-meta/CEF_ARCH"
rm -f "$DEST/VERSION" "$DEST/version" "$DEST/ARCH" "$DEST/arch"

mkdir -p "$(dirname "$VENDOR_LINK")"
rm -rf "$VENDOR_LINK"
ln -sfn "$DEST" "$VENDOR_LINK"

cat <<EOF
Installed Oriel Engine CEF:
  $DEST/Release/Chromium Embedded Framework.framework
  $DEST/include/
  $DEST/libcef_dll/   (wrapper sources)
  $VENDOR_LINK -> $DEST

Next:
  bash Scripts/build-oriel-engine-macos.sh
  # or: bash Scripts/make-macos-dmg.sh   (bundles Engine by default)

Honesty: iPhone/iPad stay WebKit-only. Oriel Engine (Blink/CEF) is Mac-only.
EOF
