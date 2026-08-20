#!/bin/bash
# Build the .deb and inject it (plus the Safari extension) into a decrypted
# YouTube IPA, producing a sideloadable YTMinimal_<version>.ipa.
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
out="YTMinimal_${version}.ipa"

./scripts/build.sh "$@"

deb=$(ls -t packages/*.deb | head -n1)
appex="Extensions/OpenYouTubeSafariExtension/OpenYouTubeSafariExtension.appex"
[ -d "$appex" ] || { echo "error: $appex missing — run: git submodule update --init" >&2; exit 1; }

rm -f "$out"
cyan -i "$ipa" -o "$out" -uwef "$deb" "$appex"
echo
echo "built: $out"
