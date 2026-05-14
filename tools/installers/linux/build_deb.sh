#!/usr/bin/env bash
set -euo pipefail

PKG_NAME="limonchero"
VERSION="${VERSION:-0.0.0}"
ARCH="${ARCH:-amd64}"
INSTALL_DIR_NAME="JuegoLimonchero"

STAGE_DIR="dist/deb/${PKG_NAME}_${VERSION}_${ARCH}"
OUT_DIR="dist/installer"
OUT_FILE="${OUT_DIR}/${PKG_NAME}-linux-${ARCH}.deb"

rm -rf "$STAGE_DIR"
mkdir -p \
  "$STAGE_DIR/DEBIAN" \
  "$STAGE_DIR/opt/${INSTALL_DIR_NAME}/game" \
  "$STAGE_DIR/opt/${INSTALL_DIR_NAME}/backend" \
  "$STAGE_DIR/usr/bin" \
  "$STAGE_DIR/usr/share/applications" \
  "$STAGE_DIR/usr/share/icons/hicolor/scalable/apps" \
  "$OUT_DIR"

cp -R dist/game/. "$STAGE_DIR/opt/${INSTALL_DIR_NAME}/game"
cp -R dist/backend/. "$STAGE_DIR/opt/${INSTALL_DIR_NAME}/backend"

cat > "$STAGE_DIR/usr/bin/limonchero" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
BASE="/opt/JuegoLimonchero"
exec "$BASE/game/limons.x86_64"
EOF
chmod +x "$STAGE_DIR/usr/bin/limonchero"

cat > "$STAGE_DIR/usr/share/applications/limonchero.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Limonchero 3D
Exec=limonchero
Icon=limonchero
Categories=Game;
EOF

cp game/icon.svg "$STAGE_DIR/usr/share/icons/hicolor/scalable/apps/limonchero.svg"

cat > "$STAGE_DIR/DEBIAN/control" <<EOF
Package: ${PKG_NAME}
Version: ${VERSION}
Section: games
Priority: optional
Architecture: ${ARCH}
Maintainer: Limonchero Team <dev@limonchero.local>
Description: Detective Noir - Limonchero 3D
 A first-person detective game built with Godot 4.
EOF

dpkg-deb --build "$STAGE_DIR" "$OUT_FILE"
