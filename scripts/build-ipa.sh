#!/bin/bash
# Build the .deb and inject it (plus the Safari extension) into a decrypted
# YouTube IPA, producing a sideloadable YTMinimal_<version>_YouTube_<yt>.ipa,
# where <yt> is the YouTube version read from the IPA itself.
#
#   ./scripts/build-ipa.sh ~/Downloads/com.google.ios.youtube-21.32.4-Decrypted.ipa
#   ./scripts/build-ipa.sh <ipa> ENABLE_ISPONSORBLOCK=0
#
# Mirrors .github/workflows/build-ipa.yml. Requires cyan (pyzule-rw):
#   pipx install --force https://github.com/asdfzxcvbn/pyzule-rw/archive/main.zip
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh

if [ $# -lt 1 ]; then
    echo "usage: $0 <path-to-decrypted-YouTube.ipa> [MAKE_FLAGS...]" >&2
    exit 1
fi

ipa="$1"; shift
[ -f "$ipa" ] || { echo "error: no such IPA: $ipa" >&2; exit 1; }
command -v cyan >/dev/null || { echo "error: cyan not on PATH — see the header of this script" >&2; exit 1; }

version=$(sed -n 's/^Version: //p' control | sed 's/~/-/g')

# Read before building, so a bad IPA fails fast. awk reads the whole listing,
# so unzip never dies of SIGPIPE under pipefail.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
plist_path=$(unzip -Z1 "$ipa" | awk '/^Payload\/[^\/]+\.app\/Info\.plist$/ && !found { print; found = 1 }')
[ -n "$plist_path" ] || { echo "error: no Payload/*.app/Info.plist in $ipa" >&2; exit 1; }
unzip -p "$ipa" "$plist_path" > "$tmp/Info.plist"
yt_version=$(plutil -extract CFBundleShortVersionString raw -o - "$tmp/Info.plist")
[[ "$yt_version" =~ ^[0-9A-Za-z._-]+$ ]] || { echo "error: unexpected YouTube version string: $yt_version" >&2; exit 1; }

out="YTMinimal_${version}_YouTube_${yt_version}.ipa"

./scripts/build.sh "$@"

deb=$(ls -t packages/*.deb | head -n1)
appex="Extensions/OpenYouTubeSafariExtension/OpenYouTubeSafariExtension.appex"
[ -d "$appex" ] || { echo "error: $appex missing — run: git submodule update --init" >&2; exit 1; }

rm -f "$out"
cyan -i "$ipa" -o "$out" -uwef "$deb" "$appex"
echo
echo "built: $out"
