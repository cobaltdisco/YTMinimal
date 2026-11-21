#!/bin/bash
# Shared environment for local Theos builds. Source this, don't run it.
#
#   THEOS      – Theos checkout (SDK expected at $THEOS/sdks/iPhoneOS16.5.sdk)
#   PATH       – Homebrew GNU make 4.x must win over macOS' /usr/bin/make 3.81,
#                Theos' makefiles do not work with 3.81.

export THEOS="${THEOS:-$HOME/theos}"

if [ -d /opt/homebrew/opt/make/libexec/gnubin ]; then
    export PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"
elif [ -d /usr/local/opt/make/libexec/gnubin ]; then
    export PATH="/usr/local/opt/make/libexec/gnubin:$PATH"
fi

# cyan (pyzule-rw) is installed by pipx into ~/.local/bin
export PATH="$HOME/.local/bin:$PATH"

if [ ! -d "$THEOS" ]; then
    echo "error: Theos not found at $THEOS — see CLAUDE.md" >&2
    return 1 2>/dev/null || exit 1
fi

if [ ! -d "$THEOS/sdks/iPhoneOS16.5.sdk" ]; then
    echo "error: iPhoneOS16.5.sdk missing from $THEOS/sdks — see CLAUDE.md" >&2
    return 1 2>/dev/null || exit 1
fi

# Tool versions CI builds with (scripts/versions.env). A different local Theos
# still builds, so this only warns: the result may just not match CI's.
_ytm_versions="$(dirname "${BASH_SOURCE[0]}")/versions.env"
YTM_THEOS_REF=$(sed -n 's/^THEOS_REF=//p' "$_ytm_versions")
YTM_CYAN_REF=$(sed -n 's/^CYAN_REF=//p' "$_ytm_versions")
_ytm_theos_head=$(git -C "$THEOS" rev-parse HEAD 2>/dev/null || true)
if [ -n "$YTM_THEOS_REF" ] && [ "$_ytm_theos_head" != "$YTM_THEOS_REF" ]; then
    echo "warning: $THEOS is at ${_ytm_theos_head:-an unknown commit}, CI builds with Theos $YTM_THEOS_REF (scripts/versions.env)" >&2
    echo "         to match: git -C \"$THEOS\" fetch origin && git -C \"$THEOS\" checkout $YTM_THEOS_REF && git -C \"$THEOS\" submodule update --init --recursive" >&2
fi
unset _ytm_versions _ytm_theos_head
