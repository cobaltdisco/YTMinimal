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
