#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="CodexTokenWatch"
VERSION="${VERSION:-1.0.1}"
ARCH="${ARCH:-$(uname -m)}"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION-$ARCH.dmg"
WORK_DIR="$(mktemp -d)"
STAGING_DIR="$WORK_DIR/staging"
RAW_DMG="$WORK_DIR/$APP_NAME-raw.dmg"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

case "$DMG_PATH" in
    "$ROOT_DIR"/*) ;;
    *) echo "Refusing to write outside the project directory" >&2; exit 1 ;;
esac

VERSION="$VERSION" "$ROOT_DIR/scripts/build-app.sh"

mkdir -p "$STAGING_DIR"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"
echo "Creating $DMG_PATH..."
hdiutil makehybrid \
    -hfs \
    -hfs-volume-name "$APP_NAME" \
    -o "$RAW_DMG" \
    "$STAGING_DIR"
hdiutil convert \
    "$RAW_DMG" \
    -format UDZO \
    -o "$DMG_PATH"

if [[ "${CODESIGN_IDENTITY:--}" != "-" ]]; then
    codesign --force --timestamp --sign "$CODESIGN_IDENTITY" "$DMG_PATH"
fi

hdiutil verify "$DMG_PATH"
shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"

echo "Created $DMG_PATH"
echo "Checksum: $DMG_PATH.sha256"
