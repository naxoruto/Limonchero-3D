#!/usr/bin/env bash
set -euo pipefail

APP_NAME="limons.app"
STAGING="dist/dmg"
OUT_DIR="dist/installer"
OUT_FILE="$OUT_DIR/limonchero-macos.dmg"

rm -rf "$STAGING"
mkdir -p "$STAGING" "$OUT_DIR"

cp -R "dist/game/$APP_NAME" "$STAGING/$APP_NAME"

BACKEND_TARGET="$STAGING/$APP_NAME/Contents/Resources/backend"
mkdir -p "$BACKEND_TARGET"
cp -R dist/backend/. "$BACKEND_TARGET"
chmod +x "$BACKEND_TARGET/limonchero-backend"

hdiutil create -volname "Limonchero 3D" -srcfolder "$STAGING" -ov -format UDZO "$OUT_FILE"
