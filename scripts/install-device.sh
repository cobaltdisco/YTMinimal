#!/bin/bash
# Re-sign a built YTMinimal IPA with a local development certificate and
# install it on a USB/Wi-Fi paired iPhone, then launch it.
#
#   ./scripts/install-device.sh YTMinimal_1.1.1_YouTube_21.43.5.ipa "iPhone Air"
#   ./scripts/install-device.sh <ipa> <UDID>
#
# The device is matched against the names and UDIDs that
# `xcrun devicectl list devices` shows; any unique substring works.
#
# Settings come from the environment, or from scripts/local.env (git-ignored,
# so personal values stay out of the repo), e.g.
#   YTM_BUNDLE_ID=com.yourname.ytminimal
#
# Settings:
#   YTM_BUNDLE_ID  bundle id to install as     (required)
#   YTM_IDENTITY   SHA-1 of the signing cert   (default: first "Apple Development")
#   YTM_PROFILE    .mobileprovision to embed   (default: picked, see below)
#   YTM_NO_LAUNCH  set to 1 to skip launching
#
# Keep the same bundle id between installs: the app is then replaced in place
# and keeps its sign-in and data. The profile is picked from Xcode's store as
# the one that is unexpired, holds the identity's certificate, lists the
# device, and covers the bundle id — an exact App ID first, else a wildcard.
# Only the basic entitlements are granted (no App Groups, no push), which is
# what a wildcard profile allows; SideloadFixes.xm covers the rest.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f scripts/local.env ] && source scripts/local.env

if [ $# -lt 2 ]; then
    echo "usage: $0 <YTMinimal_*.ipa> <device name or UDID>" >&2
    exit 1
fi
ipa="$1"; device_query="$2"
bundle_id="${YTM_BUNDLE_ID:-}"
[ -n "$bundle_id" ] || { echo "error: set YTM_BUNDLE_ID, e.g. in scripts/local.env — see the header of this script" >&2; exit 1; }
[ -f "$ipa" ] || { echo "error: no such IPA: $ipa" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# --- device -----------------------------------------------------------------
xcrun devicectl list devices --json-output "$tmp/devices.json" >/dev/null
udid=$(python3 -I - "$tmp/devices.json" "$device_query" <<'PY'
import json, sys
devs = json.load(open(sys.argv[1]))["result"]["devices"]
q = sys.argv[2].lower()
hits = []
for d in devs:
    hw = d.get("hardwareProperties", {})
    if hw.get("reality") != "physical":
        continue
    name = d.get("deviceProperties", {}).get("name", "")
    udid = hw.get("udid", "")
    if q in name.lower() or q in udid.lower():
        hits.append((udid, name))
if len(hits) != 1:
    found = ", ".join(n for _, n in hits) or "none"
    sys.exit(f"error: '{sys.argv[2]}' matches {len(hits)} physical devices ({found})")
print(hits[0][0])
PY
)
echo "device:   $udid"

# --- identity and profile ---------------------------------------------------
identity="${YTM_IDENTITY:-$(security find-identity -v -p codesigning \
    | awk '/"Apple Development:/ { print $2; exit }')}"
[ -n "$identity" ] || { echo "error: no Apple Development identity in the keychain" >&2; exit 1; }
echo "identity: $identity"

profile="${YTM_PROFILE:-}"
if [ -z "$profile" ]; then
    for f in "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"/*.mobileprovision \
             "$HOME/Library/MobileDevice/Provisioning Profiles"/*.mobileprovision; do
        [ -f "$f" ] || continue
        security cms -D -i "$f" > "$tmp/$(basename "$f").plist" 2>/dev/null || true
    done
    profile=$(python3 -I - "$tmp" "$identity" "$udid" "$bundle_id" <<'PY'
import datetime, glob, hashlib, os, plistlib, sys
tmp, ident, udid, bid = sys.argv[1:]
best = None
for path in glob.glob(os.path.join(tmp, "*.mobileprovision.plist")):
    try:
        p = plistlib.load(open(path, "rb"))
    except Exception:
        continue
    if p["ExpirationDate"] < datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None):
        continue
    if ident.upper() not in {hashlib.sha1(c).hexdigest().upper() for c in p.get("DeveloperCertificates", [])}:
        continue
    if udid not in p.get("ProvisionedDevices", []):
        continue
    team = p["TeamIdentifier"][0]
    appid = p["Entitlements"]["application-identifier"]
    rank = 0 if appid == f"{team}.{bid}" else 1 if appid == f"{team}.*" else None
    if rank is None:
        continue
    if best is None or rank < best[0]:
        best = (rank, path)
if best is None:
    sys.exit("error: no unexpired profile with this certificate, this device and a matching App ID.\n"
             "       Open any project in Xcode with automatic signing for this device, or set YTM_PROFILE.")
src = os.path.basename(best[1])[:-len(".plist")]
for d in ("~/Library/Developer/Xcode/UserData/Provisioning Profiles", "~/Library/MobileDevice/Provisioning Profiles"):
    f = os.path.join(os.path.expanduser(d), src)
    if os.path.exists(f):
        print(f)
        break
PY
)
fi
[ -f "$profile" ] || { echo "error: profile not found: $profile" >&2; exit 1; }
security cms -D -i "$profile" > "$tmp/profile.plist"
team=$(/usr/libexec/PlistBuddy -c 'Print TeamIdentifier:0' "$tmp/profile.plist")
echo "profile:  $(/usr/libexec/PlistBuddy -c 'Print Name' "$tmp/profile.plist") (team $team)"

# --- unpack -----------------------------------------------------------------
mkdir "$tmp/x"
unzip -q "$ipa" -d "$tmp/x"
app=$(ls -d "$tmp"/x/Payload/*.app | head -n1)
[ -f "$app/Frameworks/YTMinimal.dylib" ] || {
    echo "error: $ipa has no YTMinimal.dylib — pass the IPA from build-ipa.sh, not the decrypted one" >&2; exit 1; }
old_id=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Info.plist")

entitlements() {  # $1 = bundle id; prints the path of its entitlements file
    local f="$tmp/ent-$1.plist"
    cat > "$f" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>application-identifier</key><string>$team.$1</string>
    <key>com.apple.developer.team-identifier</key><string>$team</string>
    <key>get-task-allow</key><true/>
    <key>keychain-access-groups</key><array><string>$team.$bundle_id</string></array>
</dict></plist>
EOF
    echo "$f"
}

# --- sign, innermost first ----------------------------------------------------
find "$app" -name _CodeSignature -type d -prune -exec rm -rf {} +
find "$app" -name embedded.mobileprovision -delete
rm -rf "$app/Watch" "$app/com.apple.WatchPlaceholder" "$app/SC_Info"

sign() { codesign -f -s "$identity" --generate-entitlement-der "$@" 2>&1 | grep -v 'replacing existing signature' || true; }

find "$app" \( -name '*.dylib' -o -name '*.framework' \) -prune -print | while read -r f; do sign "$f"; done

for x in "$app"/PlugIns/*.appex "$app"/Extensions/*.appex; do
    [ -d "$x" ] || continue
    xid=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$x/Info.plist")
    new="$bundle_id${xid#"$old_id"}"
    /usr/libexec/PlistBuddy -c "Set CFBundleIdentifier $new" "$x/Info.plist"
    cp "$profile" "$x/embedded.mobileprovision"
    sign --entitlements "$(entitlements "$new")" "$x"
    echo "appex:    $new"
done

/usr/libexec/PlistBuddy -c "Set CFBundleIdentifier $bundle_id" "$app/Info.plist"
cp "$profile" "$app/embedded.mobileprovision"
sign --entitlements "$(entitlements "$bundle_id")" "$app"
codesign --verify --deep --strict "$app"
echo "app:      $bundle_id"

# --- install and launch -------------------------------------------------------
xcrun devicectl device install app --device "$udid" "$app" >/dev/null
echo "installed on $udid"
if [ "${YTM_NO_LAUNCH:-0}" != 1 ]; then
    xcrun devicectl device process launch --device "$udid" "$bundle_id" >/dev/null 2>&1 \
        && echo "launched" \
        || echo "warning: launch failed — is the device locked?" >&2
fi
