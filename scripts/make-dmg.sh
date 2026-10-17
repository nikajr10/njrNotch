#!/bin/bash
# Builds njrNotch for release (hardened runtime) and packs it into dist/njrNotch.dmg. The name has no
# version, so the README's releases/latest/download/njrNotch.dmg link always gets the newest release.
#
#   ./scripts/make-dmg.sh                      ad-hoc signed (no Apple Developer account needed)
#   SIGN_IDENTITY="Developer ID Application: …" ./scripts/make-dmg.sh   signed for notarization
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="${SIGN_IDENTITY:--}"
BUILD=build/release
rm -rf "$BUILD" dist
mkdir -p dist

xcodebuild -project njrNotch.xcodeproj -scheme njrNotch -configuration Release \
  -derivedDataPath "$BUILD" \
  ENABLE_HARDENED_RUNTIME=YES CODE_SIGN_ENTITLEMENTS="$PWD/njrNotch.entitlements" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$IDENTITY" DEVELOPMENT_TEAM= \
  OTHER_CODE_SIGN_FLAGS="--timestamp=none" \
  build | grep -E "error:|BUILD" || true

APP="$BUILD/Build/Products/Release/njrNotch.app"
[ -d "$APP" ] || { echo "Build failed"; exit 1; }
codesign --verify --strict --verbose=1 "$APP"

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "njrNotch" -srcfolder "$STAGE" -ov -format UDZO "dist/njrNotch.dmg" >/dev/null
rm -rf "$STAGE"
echo "njrNotch $VERSION"; shasum -a 256 "dist/njrNotch.dmg"
