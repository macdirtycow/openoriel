#!/usr/bin/env bash
# Build an unsigned device IPA for sideload (TrollStore / AltStore / Sideloadly).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -d "/Users/leopold/Desktop/katwijk huiselijk geweld bronnen/Xcode-beta.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Users/leopold/Desktop/katwijk huiselijk geweld bronnen/Xcode-beta.app/Contents/Developer"
fi

command -v xcodegen >/dev/null && xcodegen generate

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :objects:MARKETING_VERSION' /dev/null 2>/dev/null || true)
# Prefer project.yml
MARKETING=$(grep -E '^\s*MARKETING_VERSION:' project.yml | head -1 | sed 's/.*"\(.*\)".*/\1/')
BUILD=$(grep -E '^\s*CURRENT_PROJECT_VERSION:' project.yml | head -1 | sed 's/.*"\(.*\)".*/\1/')
MARKETING="${MARKETING:-1.0.0}"
BUILD="${BUILD:-1}"

APP_BUILD_DIR="${TMPDIR:-/tmp}/OrielDerivedIPA-${BUILD}"
OUT_DIR="$HOME/Desktop/Oriel-unsigned"
IPA_PATH="$HOME/Desktop/Oriel-${MARKETING}-${BUILD}-unsigned.ipa"

rm -rf "$APP_BUILD_DIR"
mkdir -p "$APP_BUILD_DIR" "$OUT_DIR"

echo "Building Oriel ${MARKETING} (${BUILD}) for generic iOS…"
xcodebuild \
  -scheme Oriel \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$APP_BUILD_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  ONLY_ACTIVE_ARCH=NO \
  build

APP="$APP_BUILD_DIR/Build/Products/Release-iphoneos/Oriel.app"
test -d "$APP"

STAGE="${TMPDIR:-/tmp}/OrielIPAPayload-${BUILD}"
rm -rf "$STAGE"
mkdir -p "$STAGE/Payload"
ditto "$APP" "$STAGE/Payload/Oriel.app"
ditto "$APP" "$OUT_DIR/Oriel.app"
(cd "$STAGE" && rm -f "$IPA_PATH" && zip -qry "$IPA_PATH" Payload)

# Drop previous unsigned IPA on Desktop (keep .app folder current)
find "$HOME/Desktop" -maxdepth 1 -name 'Oriel-*-unsigned.ipa' ! -name "$(basename "$IPA_PATH")" -delete 2>/dev/null || true

echo "IPA: $IPA_PATH"
ls -lh "$IPA_PATH"
plutil -p "$APP/Info.plist" | grep -E 'CFBundle(ShortVersionString|Version|Identifier)'
