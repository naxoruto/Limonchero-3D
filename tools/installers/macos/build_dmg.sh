#!/usr/bin/env bash
set -euo pipefail

SOURCE_APP="limons.app"
TARGET_APP="JuegoLimonchero.app"
STAGING="dist/dmg"
OUT_DIR="dist/installer"
OUT_FILE="$OUT_DIR/limonchero-macos.dmg"

rm -rf "$STAGING"
mkdir -p "$STAGING" "$OUT_DIR"

cp -R "dist/game/$SOURCE_APP" "$STAGING/$TARGET_APP"

BACKEND_TARGET="$STAGING/$TARGET_APP/Contents/Resources/backend"
mkdir -p "$BACKEND_TARGET"
cp -R dist/backend/. "$BACKEND_TARGET"
chmod +x "$BACKEND_TARGET/limonchero-backend"

hdiutil create -volname "JuegoLimonchero" -srcfolder "$STAGING" -ov -format UDZO "$OUT_FILE"
