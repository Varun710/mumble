#!/usr/bin/env bash
#
# Build Mumble in Release and install it into /Applications.
#
# Usage:  ./scripts/install.sh
#
# Requires: Xcode (full), XcodeGen (`brew install xcodegen`).
#
# Signs with the stable "Mumble Local Signing" identity if present (see
# scripts/create-signing-cert.sh) so Accessibility / Input Monitoring grants
# survive rebuilds; otherwise falls back to ad-hoc signing.

set -euo pipefail

APP_NAME="Mumble"
DEST="/Applications"
DERIVED="build"
IDENTITY="Mumble Local Signing"
KEYCHAIN="mumble-signing.keychain"
KEYCHAIN_PASS="mumble-local"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

cd "$(dirname "$0")/.."

echo "==> Generating Xcode project"
xcodegen generate

echo "==> Building $APP_NAME (Release, unsigned)"
xcodebuild \
  -project "$APP_NAME.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build

BUILT_APP="$DERIVED/Build/Products/Release/$APP_NAME.app"
if [[ ! -d "$BUILT_APP" ]]; then
  echo "!! Build did not produce $BUILT_APP" >&2
  exit 1
fi

# Pick a signing identity: stable self-signed if available, else ad-hoc.
SIGN_ID="-"
if security find-identity -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
  SIGN_ID="$IDENTITY"
  security unlock-keychain -p "$KEYCHAIN_PASS" "$KEYCHAIN" 2>/dev/null || true
  echo "==> Signing with stable identity: $IDENTITY"
else
  echo "==> No stable identity found — ad-hoc signing."
  echo "   (Run ./scripts/create-signing-cert.sh once so permissions persist across rebuilds.)"
fi

codesign --force --deep --options runtime --timestamp=none \
  --entitlements "$APP_NAME/Resources/$APP_NAME.entitlements" \
  -s "$SIGN_ID" "$BUILT_APP"

echo "==> Installing to $DEST/$APP_NAME.app"
osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
pkill -f "$DEST/$APP_NAME.app/Contents/MacOS/$APP_NAME" >/dev/null 2>&1 || true
sleep 1

rm -rf "${DEST:?}/$APP_NAME.app"
cp -R "$BUILT_APP" "$DEST/"

xattr -dr com.apple.quarantine "$DEST/$APP_NAME.app" 2>/dev/null || true

echo "==> Registering with Launch Services"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST/$APP_NAME.app"

echo "==> Launching $APP_NAME"
open "$DEST/$APP_NAME.app"

echo "Done. $APP_NAME is installed at $DEST/$APP_NAME.app"
