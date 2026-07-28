#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="CodexTokenWatch"
VERSION="${VERSION:-1.0.2}"
BUILD_NUMBER="${BUILD_NUMBER:-3}"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
ICON_WORK_DIR="$(mktemp -d)"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT_DIR/.build/module-cache"
export XDG_CACHE_HOME="$ROOT_DIR/.build/cache"

cleanup() {
    rm -rf "$ICON_WORK_DIR"
}
trap cleanup EXIT

case "$APP_BUNDLE" in
    "$ROOT_DIR"/*) ;;
    *) echo "Refusing to write outside the project directory" >&2; exit 1 ;;
esac

echo "Building $APP_NAME $VERSION..."
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$XDG_CACHE_HOME"
(
    cd "$ROOT_DIR"
    swift build --disable-sandbox -c release --product "$APP_NAME"
)
BIN_DIR="$(cd "$ROOT_DIR" && swift build --disable-sandbox -c release --show-bin-path)"
BIN_PATH="$BIN_DIR/$APP_NAME"

if [[ ! -x "$BIN_PATH" ]]; then
    echo "Built executable not found at $BIN_PATH" >&2
    exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
install -m 755 "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
install -m 644 "$ROOT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP_BUNDLE/Contents/Info.plist"

echo "Generating app icon..."
swift "$ROOT_DIR/scripts/generate-icon.swift" "$ICON_WORK_DIR/AppIcon-1024.png"
ICONSET="$ICON_WORK_DIR/AppIcon.iconset"
mkdir -p "$ICONSET"

for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ICON_WORK_DIR/AppIcon-1024.png" \
        --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double_size=$((size * 2))
    sips -z "$double_size" "$double_size" "$ICON_WORK_DIR/AppIcon-1024.png" \
        --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

swift "$ROOT_DIR/scripts/package-icns.swift" \
    "$ICONSET" \
    "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

SIGNING_IDENTITY="${CODESIGN_IDENTITY:--}"
echo "Signing app with identity: $SIGNING_IDENTITY"
codesign --force --deep --options runtime --timestamp=none \
    --sign "$SIGNING_IDENTITY" "$APP_BUNDLE"

plutil -lint "$APP_BUNDLE/Contents/Info.plist" >/dev/null
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

echo "Created $APP_BUNDLE"
