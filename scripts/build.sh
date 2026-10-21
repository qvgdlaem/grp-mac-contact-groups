#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/grp-clang-cache"
APP="dist/GRP.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
ARCHITECTURES=("$(uname -m)")
if [[ "${1:-}" == "--universal" ]]; then
    ARCHITECTURES=(arm64 x86_64)
elif [[ $# -gt 0 ]]; then
    printf 'Usage: bash scripts/build.sh [--universal]\n' >&2
    exit 2
fi
BINARIES=()
for ARCHITECTURE in "${ARCHITECTURES[@]}"; do
    BUILD_PATH=".build/release-$ARCHITECTURE"
    OPTIONS=(-c release --disable-sandbox --cache-path .build/cache --scratch-path "$BUILD_PATH" --triple "$ARCHITECTURE-apple-macosx14.0")
    swift build "${OPTIONS[@]}" -Xswiftc -debug-prefix-map -Xswiftc "$PWD=."
    BIN_DIR="$(swift build "${OPTIONS[@]}" --show-bin-path)"
    BINARIES+=("$BIN_DIR/GRP")
done
if [[ ${#BINARIES[@]} -gt 1 ]]; then
    lipo -create "${BINARIES[@]}" -output "$APP/Contents/MacOS/GRP"
else
    cp "${BINARIES[0]}" "$APP/Contents/MacOS/GRP"
fi
strip -S "$APP/Contents/MacOS/GRP"
cp LICENSE "$APP/Contents/Resources/LICENSE"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/Logo.svg Resources/Logo.png "$APP/Contents/Resources/"
ICONSET=".build/GRP.iconset"
mkdir -p "$ICONSET"
for SIZE in 16 32 128 256 512; do
    sips -z "$SIZE" "$SIZE" Resources/Logo.png --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
    DOUBLE=$((SIZE * 2))
    sips -z "$DOUBLE" "$DOUBLE" Resources/Logo.png --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
python3 scripts/package-icon.py "$ICONSET" "$APP/Contents/Resources/GRP.icns"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
printf 'Built %s\n' "$PWD/$APP"
