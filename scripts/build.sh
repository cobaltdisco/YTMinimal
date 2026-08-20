#!/bin/bash
# Build the tweak bundle as a .deb into ./packages.
#
#   ./scripts/build.sh                        # everything enabled
#   ./scripts/build.sh ENABLE_ISPONSORBLOCK=0 # any ENABLE_* flag from the Makefile
#   ./scripts/build.sh clean package          # extra make targets pass through
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/env.sh

args=("$@")
has_target=0
for a in "${args[@]:-}"; do
    case "$a" in
        *=*) ;;
        "") ;;
        *) has_target=1 ;;
    esac
done
if [ "$has_target" -eq 0 ]; then
    args=(package "${args[@]:-}")
fi

make "${args[@]}" FINALPACKAGE=1
echo
echo "built: $(ls -t packages/*.deb | head -n1)"
