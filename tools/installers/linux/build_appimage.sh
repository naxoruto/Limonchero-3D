#!/usr/bin/env bash
set -euo pipefail

APPDIR="dist/appimage/AppDir"
OUT_DIR="dist/installer"
OUT_FILE="$OUT_DIR/limonchero-linux-x86_64.AppImage"

rm -rf "$APPDIR"
mkdir -p "$APPDIR/game" "$APPDIR/backend" "$OUT_DIR"
cp -R dist/game/. "$APPDIR/game"
cp -R dist/backend/. "$APPDIR/backend"

cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/game/limons.x86_64"
EOF
chmod +x "$APPDIR/AppRun"

cat > "$APPDIR/limonchero.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Limonchero 3D
Exec=AppRun
Icon=limonchero
Categories=Game;
EOF

cp game/icon.svg "$APPDIR/limonchero.svg"

TOOL="dist/appimage/appimagetool.AppImage"
if [ ! -f "$TOOL" ]; then
  mkdir -p "$(dirname "$TOOL")"
  curl -L -o "$TOOL" \
    "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
  chmod +x "$TOOL"
fi

export APPIMAGE_EXTRACT_AND_RUN=1
"$TOOL" "$APPDIR" "$OUT_FILE"
