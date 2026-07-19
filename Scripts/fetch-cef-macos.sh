#!/usr/bin/env bash
# Download Chromium Embedded Framework (CEF) Standard Distribution for Mac Oriel Native.
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

# Pinned stable-ish Standard builds (Chromium 144). Override with ORIEL_CEF_URL.
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

echo "Oriel CEF fetch"
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
FRAMEWORK="$(find "$TMP" -type d -name 'Chromium Embedded Framework.framework' | head -1 || true)"
if [[ -z "$FRAMEWORK" ]]; then
  echo "error: Chromium Embedded Framework.framework not found in archive" >&2
  exit 1
fi

rm -rf "$DEST/Chromium Embedded Framework.framework"
rm -rf "$DEST/include" "$DEST/libcef_dll" "$DEST/libcef_dll_wrapper" "$DEST/CMakeLists.txt" "$DEST/VERSION"
cp -R "$FRAMEWORK" "$DEST/"

# Headers + wrapper sources for ORIEL_HAS_CEF builds (enable-cef-macos.sh).
if [[ -n "$EXTRACT_ROOT" ]]; then
  [[ -d "$EXTRACT_ROOT/include" ]] && cp -R "$EXTRACT_ROOT/include" "$DEST/"
  [[ -d "$EXTRACT_ROOT/libcef_dll" ]] && cp -R "$EXTRACT_ROOT/libcef_dll" "$DEST/"
  [[ -d "$EXTRACT_ROOT/libcef_dll_wrapper" ]] && cp -R "$EXTRACT_ROOT/libcef_dll_wrapper" "$DEST/"
  [[ -f "$EXTRACT_ROOT/CMakeLists.txt" ]] && cp "$EXTRACT_ROOT/CMakeLists.txt" "$DEST/"
fi
printf '%s\n' "$PIN_VERSION" > "$DEST/VERSION"
printf '%s\n' "$ARCH" > "$DEST/ARCH"

# Convenience symlink for local Xcode HEADER_SEARCH_PATHS (gitignored).
mkdir -p "$(dirname "$VENDOR_LINK")"
rm -rf "$VENDOR_LINK"
ln -s "$DEST" "$VENDOR_LINK"

cat <<EOF
Installed:
  $DEST/Chromium Embedded Framework.framework
  $DEST/include/   (for ORIEL_HAS_CEF compile)
  $VENDOR_LINK -> $DEST

Next:
  bash Scripts/enable-cef-macos.sh
  # then: xcodegen generate && open Oriel.xcodeproj
  # Build Mac target — Chromium Native embeds Blink in-tab when ORIEL_HAS_CEF=1.

Until the app is built with ORIEL_HAS_CEF, Native still uses managed Chromium app-windows
(real Blink process) when Chrome/Brave/Edge/Arc is installed.
EOF
