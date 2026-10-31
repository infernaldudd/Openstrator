#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Resources/OpenstratorMark.png"
ICONSET="${TMPDIR:-/tmp}/Openstrator.iconset"
OUT="$ROOT/Resources/Openstrator.icns"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
for spec in '16 16x16' '32 16x16@2x' '32 32x32' '64 32x32@2x' '128 128x128' '256 128x128@2x' '256 256x256' '512 256x256@2x' '512 512x512' '1024 512x512@2x'; do
  set -- $spec; px="$1"; name="$2"
  sips -z "$px" "$px" "$SRC" --out "$ICONSET/icon_${name}.png" >/dev/null
 done
iconutil -c icns "$ICONSET" -o "$OUT"
rm -rf "$ICONSET"
echo "rebuilt $OUT"
