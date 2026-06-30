#!/usr/bin/env bash
# Diagnose macOS 26 Tahoe menu bar registration for Mumble.
# Run in Terminal: ./scripts/diagnose-menu-bar.sh

set -euo pipefail

CC_PLIST="$HOME/Library/Group Containers/group.com.apple.controlcenter/Library/Preferences/group.com.apple.controlcenter.plist"

echo "==> Installed Mumble"
if [[ -d /Applications/Mumble.app ]]; then
  /usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' /Applications/Mumble.app/Contents/Info.plist
  codesign -dv /Applications/Mumble.app 2>&1 | rg 'Identifier=|TeamIdentifier=|Signed Time=' || true
else
  echo "   /Applications/Mumble.app not found"
fi

echo
echo "==> Other Mumble bundles on disk (can confuse Tahoe)"
mdfind "kMDItemCFBundleIdentifier == 'com.mumble.app' || kMDItemCFBundleIdentifier == 'app.mumble.Mumble'" 2>/dev/null || true

echo
echo "==> Control Center trackedApplications (menu bar allow-list)"
if [[ ! -f "$CC_PLIST" ]]; then
  echo "   plist not found: $CC_PLIST"
  exit 0
fi

python3 <<'PY'
import plistlib, os, base64, sys
plist_path = os.path.expanduser("~/Library/Group Containers/group.com.apple.controlcenter/Library/Preferences/group.com.apple.controlcenter.plist")
with open(plist_path, "rb") as f:
    root = plistlib.load(f)
tracked = root.get("trackedApplications")
if tracked is None:
    print("   no trackedApplications key")
    sys.exit(0)
if isinstance(tracked, bytes):
    tracked = plistlib.loads(tracked)
elif isinstance(tracked, str):
    tracked = plistlib.loads(base64.b64decode(tracked))

needles = ("mumble", "purr", "com.mumble", "app.mumble")
print(f"   {len(tracked)} tracked entries")
for key, val in sorted(tracked.items()):
    bid = key
    if isinstance(val, dict):
        loc = val.get("location", {})
        if isinstance(loc, dict):
            bundle = loc.get("bundle", {})
            if isinstance(bundle, dict):
                bid = bundle.get("_0", key)
    blob = (str(bid) + str(val)).lower()
    if any(n in blob for n in needles):
        allowed = val.get("isAllowed") if isinstance(val, dict) else "?"
        print(f"   - {bid}: isAllowed={allowed}")
        if isinstance(val, dict) and val.get("menuItemLocations"):
            print(f"     menuItemLocations={val.get('menuItemLocations')}")

print()
print("If Mumble is missing above, Tahoe never registered it — reinstall with the new bundle id,")
print("quit Mumble fully, reopen from /Applications, then check System Settings → Menu Bar.")
print("Ghost apps like 'purr' are stale Tahoe entries from deleted dev builds; safe to ignore.")
PY
