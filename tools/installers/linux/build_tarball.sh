#!/usr/bin/env bash
set -euo pipefail

ARCH="${ARCH:-x86_64}"

STAGE_DIR="dist/tar/JuegoLimonchero"
OUT_DIR="dist/installer"
OUT_FILE="${OUT_DIR}/limonchero-linux-${ARCH}.tar.gz"

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/game" "$STAGE_DIR/backend" "$OUT_DIR"

cp -R dist/game/. "$STAGE_DIR/game"
cp -R dist/backend/. "$STAGE_DIR/backend"

cat > "$STAGE_DIR/run.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$BASE_DIR/game/limons.x86_64"
EOF
chmod +x "$STAGE_DIR/run.sh"

TAR_ROOT="$(dirname "$STAGE_DIR")"
TAR_FOLDER="$(basename "$STAGE_DIR")"

tar -C "$TAR_ROOT" -czf "$OUT_FILE" "$TAR_FOLDER"
