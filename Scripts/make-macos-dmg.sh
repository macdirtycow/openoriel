#!/usr/bin/env bash
# Build a macOS Release .app and package it as a drag-and-drop DMG for GitHub Releases.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MARKETING="$(grep -E '^\s*MARKETING_VERSION:' project.yml | head -1 | sed 's/.*"\(.*\)".*/\1/')"
BUILD="$(grep -E '^\s*CURRENT_PROJECT_VERSION:' project.yml | head -1 | sed 's/.*"\(.*\)".*/\1/')"
MARKETING="${MARKETING:-1.0.0}"
BUILD="${BUILD:-1}"

OUT_DIR="${ORIEL_DMG_OUT:-$ROOT/build/dmg}"
DERIVED="${ORIEL_DERIVED_DATA:-$ROOT/build/DerivedData-dmg}"
STAGE="$OUT_DIR/stage"
VOL_NAME="Oriel"
DMG_NAME="Oriel-${MARKETING}-${BUILD}-macOS.dmg"
DMG_PATH="$OUT_DIR/$DMG_NAME"

echo "-> Building Oriel ${MARKETING} (${BUILD}) for macOS..."

if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate -q
fi

rm -rf "${DERIVED}" "${OUT_DIR}"
mkdir -p "${STAGE}" "${OUT_DIR}"

# Ad-hoc sign so the binary is runnable; notarization can be added later with release secrets.
xcodebuild \
  -scheme Oriel \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED" \
  -quiet \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES \
  DEVELOPMENT_TEAM= \
  CURRENT_PROJECT_VERSION="$BUILD" \
  MARKETING_VERSION="$MARKETING" \
  build

APP="$(find "$DERIVED/Build/Products" -maxdepth 2 -type d -name 'Oriel.app' | head -1)"
if [[ -z "$APP" || ! -d "$APP" ]]; then
  echo "error: Oriel.app not found under $DERIVED/Build/Products" >&2
  exit 1
fi

echo "-> Staging DMG contents..."
ditto "${APP}" "${STAGE}/Oriel.app"
ln -sf /Applications "${STAGE}/Applications"

echo "-> Creating ${DMG_NAME}..."
rm -f "${DMG_PATH}"
hdiutil create \
  -volname "${VOL_NAME}" \
  -srcfolder "${STAGE}" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  "${DMG_PATH}" >/dev/null

rm -rf "${STAGE}"

shasum -a 256 "${DMG_PATH}" | tee "${DMG_PATH}.sha256"

echo ""
echo "OK: DMG ready: ${DMG_PATH}"
echo "  Open the DMG and drag Oriel into Applications."
echo "  Unsigned / ad-hoc builds: right-click Oriel -> Open the first time (Gatekeeper)."
