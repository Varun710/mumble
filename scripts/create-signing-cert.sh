#!/usr/bin/env bash
#
# Creates a stable, self-signed code-signing identity in a dedicated keychain.
#
# Why: macOS ties Accessibility / Input Monitoring grants to an app's code
# signature. Ad-hoc signing changes on every rebuild, so permissions break each
# time you reinstall. Signing with a *stable* identity keeps the grant working
# across rebuilds. Run this once; then use ./scripts/install.sh as usual.

set -euo pipefail

IDENTITY="Mumble Local Signing"
KEYCHAIN="mumble-signing.keychain"
KEYCHAIN_PATH="$HOME/Library/Keychains/${KEYCHAIN}-db"
PASS="mumble-local"

if security find-identity -v -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
  echo "Signing identity '$IDENTITY' already exists. Nothing to do."
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> Generating self-signed code-signing certificate"
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -days 3650 \
  -subj "/CN=$IDENTITY" \
  -addext "basicConstraints=critical,CA:false" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning"

# Use a SHA1 MAC + 3DES PBE so Apple's `security import` can read the bundle.
openssl pkcs12 -export -out "$TMP/identity.p12" \
  -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -macalg sha1 -certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES \
  -passout pass:"$PASS"

echo "==> Creating dedicated signing keychain"
security delete-keychain "$KEYCHAIN" 2>/dev/null || true
security create-keychain -p "$PASS" "$KEYCHAIN"
security set-keychain-settings "$KEYCHAIN"            # no auto-lock timeout
security unlock-keychain -p "$PASS" "$KEYCHAIN"

echo "==> Importing certificate (authorizing codesign)"
security import "$TMP/identity.p12" -k "$KEYCHAIN" -P "$PASS" -A -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$PASS" "$KEYCHAIN" >/dev/null 2>&1

# Add the keychain to the user search list (preserving existing entries).
EXISTING=$(security list-keychains -d user | sed -e 's/"//g' -e 's/^[[:space:]]*//')
# shellcheck disable=SC2086
security list-keychains -d user -s "$KEYCHAIN_PATH" $EXISTING

echo "==> Done. Code-signing identity:"
security find-identity -v -p codesigning | grep "$IDENTITY" || true
