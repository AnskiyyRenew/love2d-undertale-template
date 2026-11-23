#!/bin/sh
# Run the game with the portable LOVE installed by setup/install.sh.
#
# Looks in this order: $SE_LOVE, Packager/tools/love, then PATH.
# Extra arguments are forwarded to LOVE, e.g.  ./play.sh --console

set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)

LOVE=${SE_LOVE:-}
if [ -z "$LOVE" ]; then
    for candidate in \
        "$HERE/tools/love/love" \
        "$HERE/tools/love/love.AppImage" \
        "$HERE/tools/love/love.app/Contents/MacOS/love"
    do
        if [ -e "$candidate" ]; then
            LOVE=$candidate
            break
        fi
    done
fi
if [ -z "$LOVE" ]; then
    LOVE=$(command -v love || true)
fi

if [ -z "$LOVE" ]; then
    printf '[error] LOVE was not found.\n' >&2
    printf '        install it with: Packager/setup/install.sh\n' >&2
    printf '        or point SE_LOVE at an existing binary\n' >&2
    exit 1
fi

# AppImages need libfuse2. Ubuntu 22.04+ ships without it, and the runtime then
# fails with a bare "cannot execute" message, so fall back to the self-extract
# mode that needs no FUSE at all.
EXTRA=""
case "$LOVE" in
    *.AppImage)
        if ! ldconfig -p 2>/dev/null | grep -q 'libfuse\.so\.2'; then
            EXTRA="--appimage-extract-and-run"
        fi
        ;;
esac

# shellcheck disable=SC2086  # EXTRA is intentionally word-split (may be empty)
exec "$LOVE" $EXTRA "$ROOT" "$@"
