#!/bin/sh
# Packager/setup/install.sh -- portable LOVE runtime installer for Linux / macOS.
#
# Downloads the LOVE build listed in setup.conf, unwraps it into
# Packager/tools/love and checks that it starts. Nothing is installed outside
# the repository, so deleting that folder is a clean uninstall.
#
#   ./install.sh            install or refresh
#   ./install.sh --check    environment report only, no download
#   ./install.sh --force    reinstall even if a copy exists
#   ./install.sh --url URL  override the URL for this run only
#   ./install.sh --dest DIR override the target folder for this run only
#
# --platform linux|macos exists for testing the other platform's layout from a
# machine that is not that platform.

set -eu

SETUP_DIR=$(cd "$(dirname "$0")" && pwd)
PACKAGER_DIR=$(cd "$SETUP_DIR/.." && pwd)
GAME_DIR=$(cd "$PACKAGER_DIR/.." && pwd)
CONF="$SETUP_DIR/setup.conf"

FORCE=0
CHECK=0
URL_OVERRIDE=""
DEST_OVERRIDE=""
PLATFORM_OVERRIDE=""

usage() {
    sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
    case "$1" in
        -f|--force) FORCE=1 ;;
        -c|--check) CHECK=1 ;;
        -u|--url) shift; URL_OVERRIDE=${1:-} ;;
        -d|--dest) shift; DEST_OVERRIDE=${1:-} ;;
        --platform) shift; PLATFORM_OVERRIDE=${1:-} ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

# --- config ---------------------------------------------------------------
# Plain KEY=VALUE parsing instead of sourcing, so a stray character in a URL
# cannot turn into shell code.
cfg_get() {
    _key=$1
    [ -f "$CONF" ] || return 0
    awk -v want="$_key" '
        { sub(/\r$/, "") }
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*$/ { next }
        {
            i = index($0, "=")
            if (i == 0) next
            k = substr($0, 1, i - 1)
            v = substr($0, i + 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
            if (k != want) next
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
            gsub(/^"|"$/, "", v)
            gsub(/^'\''|'\''$/, "", v)
            print v
            exit
        }' "$CONF"
}

# --- platform -------------------------------------------------------------
if [ -n "$PLATFORM_OVERRIDE" ]; then
    os=$PLATFORM_OVERRIDE
else
    case "$(uname -s)" in
        Linux) os=linux ;;
        Darwin) os=macos ;;
        *)
            printf '[error] unsupported system: %s (this script covers Linux and macOS)\n' "$(uname -s)" >&2
            printf '        on Windows use install.bat\n' >&2
            exit 1
            ;;
    esac
fi

case "$(uname -m)" in
    x86_64|amd64) arch=x64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) arch=$(uname -m) ;;
esac

if [ -n "$URL_OVERRIDE" ]; then
    url=$URL_OVERRIDE
elif [ "$os" = macos ]; then
    url=$(cfg_get LOVE_MACOS)
else
    url=$(cfg_get "LOVE_LINUX_$(printf '%s' "$arch" | tr 'a-z' 'A-Z')")
fi

DEST=${DEST_OVERRIDE:-$(cfg_get DEST)}
[ -n "$DEST" ] || DEST=tools/love
case "$DEST" in
    /*) dest=$DEST ;;
    *) dest=$PACKAGER_DIR/$DEST ;;
esac

CACHE=$(cfg_get CACHE)
[ -n "$CACHE" ] || CACHE=tools/cache
case "$CACHE" in
    /*) cache_dir=$CACHE ;;
    *) cache_dir=$PACKAGER_DIR/$CACHE ;;
esac

KEEP_ARCHIVE=$(cfg_get KEEP_ARCHIVE)
[ -n "$KEEP_ARCHIVE" ] || KEEP_ARCHIVE=0

# --- helpers --------------------------------------------------------------
love_bin() {   # prints the runnable LOVE binary inside an install dir, if any
    for c in "$1/love" "$1/love.AppImage" "$1/love.app/Contents/MacOS/love"; do
        [ -e "$c" ] && { printf '%s\n' "$c"; return 0; }
    done
    return 1
}

love_version() {   # $1 = binary
    "$1" --version 2>/dev/null | head -n 1 || true
}

fetch() {   # $1 url, $2 out
    rm -f "$2"
    if command -v curl >/dev/null 2>&1; then
        # -sS: no progress meter (we print our own line), but keep error text.
        curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 20 -o "$2" "$1"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$2" "$1"
    else
        printf '[error] neither curl nor wget is available\n' >&2
        return 1
    fi
}

unzip_into() {   # $1 archive, $2 dir
    mkdir -p "$2"
    if command -v unzip >/dev/null 2>&1; then
        unzip -q -o "$1" -d "$2"
    elif command -v ditto >/dev/null 2>&1; then
        ditto -x -k "$1" "$2"
    elif command -v bsdtar >/dev/null 2>&1; then
        bsdtar -xf "$1" -C "$2"
    elif command -v python3 >/dev/null 2>&1; then
        python3 -m zipfile -e "$1" "$2"
    else
        printf '[error] no unzip, ditto, bsdtar or python3 available to extract %s\n' "$1" >&2
        return 1
    fi
}

find_payload() {   # $1 dir -> path of the interesting item, or nothing
    if [ "$os" = macos ]; then
        find "$1" -maxdepth 4 -type d -name '*.app' 2>/dev/null | head -n 1
    else
        find "$1" -maxdepth 4 -type f -name '*.AppImage' 2>/dev/null | head -n 1
    fi
}

installed_bin=""
if love_bin "$dest" >/dev/null 2>&1; then
    installed_bin=$(love_bin "$dest")
fi

# --- check mode -----------------------------------------------------------
if [ "$CHECK" -eq 1 ]; then
    printf 'SoulEngine - LOVE environment report\n'
    printf '\n== System\n'
    printf '   platform      : %s (%s)\n' "$os" "$arch"
    printf '   kernel        : %s\n' "$(uname -sr)"
    printf '   repo root     : %s\n' "$GAME_DIR"

    printf '\n== LOVE\n'
    printf '   target        : %s\n' "$dest"
    if [ -n "$installed_bin" ]; then
        printf '   installed     : yes (%s)\n' "$installed_bin"
        printf '   version       : %s\n' "$(love_version "$installed_bin")"
    else
        printf '   installed     : no\n'
        printf '                   run ./install.sh to download it\n'
    fi
    if [ -n "$url" ]; then
        printf '   source        : %s\n' "$url"
    else
        printf '   [warn] no download URL configured for this platform\n'
    fi
    if [ "$os" = linux ] && [ -n "$installed_bin" ]; then
        case "$installed_bin" in
            *.AppImage)
                if ! ldconfig -p 2>/dev/null | grep -q 'libfuse\.so\.2'; then
                    printf '   [warn] libfuse2 not found; play.sh will fall back to --appimage-extract-and-run\n'
                    printf '          to avoid the slow fallback: sudo apt install libfuse2\n'
                fi
                ;;
        esac
    fi

    printf '\n== Optional tooling\n'
    if command -v git >/dev/null 2>&1; then
        printf '   git           : %s\n' "$(command -v git)"
    else
        printf '   git           : not found (only needed to clone love-android)\n'
    fi
    if command -v python3 >/dev/null 2>&1; then
        printf '   python3       : %s\n' "$(command -v python3)"
    else
        printf '   python3       : not found (only needed for the packager GUI)\n'
    fi
    if [ -d "$PACKAGER_DIR/love-android" ]; then
        printf '   love-android  : present\n'
    else
        printf '   love-android  : missing (only needed for APK builds)\n'
    fi
    printf '\n'
    exit 0
fi

# --- already installed? ---------------------------------------------------
if [ -n "$installed_bin" ] && [ "$FORCE" -ne 1 ]; then
    printf 'LOVE is already installed - nothing to do.\n'
    printf '   path    : %s\n' "$dest"
    printf '   version : %s\n' "$(love_version "$installed_bin")"
    printf '   reinstall with: ./install.sh --force\n'
    printf '   run the game  : Packager/play.sh\n'
    exit 0
fi

# --- install --------------------------------------------------------------
printf 'SoulEngine - LOVE setup\n'
printf '\n== Resolving download\n'
if [ -z "$url" ]; then
    printf '   [error] no URL configured for %s %s\n' "$os" "$arch" >&2
    printf '           set the matching LOVE_* key in Packager/setup/setup.conf\n' >&2
    exit 1
fi
printf '   url  : %s\n' "$url"
printf '   dest : %s\n' "$dest"

printf '\n== Downloading\n'
mkdir -p "$cache_dir"
archive_name=$(printf '%s' "$url" | sed 's/[?#].*$//' | sed 's|.*/||')
[ -n "$archive_name" ] || archive_name=love-download.zip
archive="$cache_dir/$archive_name"

if [ -f "$archive" ]; then
    printf '   using cached archive: %s\n' "$archive"
else
    printf '   downloading (roughly 10-20 MB)\n'
    fetch "$url" "$archive"
    printf '   saved %s MB\n' "$(du -m "$archive" 2>/dev/null | cut -f1)"
fi

printf '\n== Installing\n'
work=$(mktemp -d "${TMPDIR:-/tmp}/se-love.XXXXXX")
trap 'rm -rf "$work"' EXIT INT TERM

if ! unzip_into "$archive" "$work"; then
    printf '   [error] failed to extract %s\n' "$archive" >&2
    exit 1
fi

payload=""
round=0
while [ "$round" -lt 3 ]; do
    payload=$(find_payload "$work")
    [ -n "$payload" ] && break
    inner=$(find "$work" -maxdepth 4 -type f -name '*.zip' 2>/dev/null | head -n 1)
    [ -n "$inner" ] || break
    printf '   unwrapping nested archive: %s\n' "$(basename "$inner")"
    if ! unzip_into "$inner" "$work/inner$round"; then
        printf '   [error] failed to extract %s\n' "$inner" >&2
        exit 1
    fi
    rm -f "$inner"
    round=$((round + 1))
done

if [ -z "$payload" ]; then
    printf '   [error] no %s found inside the archive\n' \
        "$([ "$os" = macos ] && printf 'love.app' || printf '.AppImage')" >&2
    exit 1
fi

case "$dest" in
    ""|"/") printf '   [error] refusing to use %s as the install folder\n' "$dest" >&2; exit 1 ;;
esac
rm -rf "$dest"
mkdir -p "$dest"

if [ "$os" = macos ]; then
    cp -R "$payload" "$dest/love.app"
    chmod +x "$dest/love.app/Contents/MacOS/love" 2>/dev/null || true
    # Nightly builds are unsigned; clearing the quarantine flag keeps Gatekeeper
    # from refusing to launch a binary that never came through a browser.
    if command -v xattr >/dev/null 2>&1; then
        xattr -dr com.apple.quarantine "$dest/love.app" 2>/dev/null || true
    fi
else
    cp "$payload" "$dest/love.AppImage"
    chmod +x "$dest/love.AppImage"
fi

printf '\n== Verifying\n'
bin=$(love_bin "$dest" || true)
if [ -z "$bin" ]; then
    printf '   [error] install finished but no runnable LOVE binary was found in %s\n' "$dest" >&2
    exit 1
fi
version=$(love_version "$bin")
if [ -n "$version" ]; then
    printf '   %s\n' "$version"
else
    printf '   [warn] could not read the version string; try Packager/play.sh\n'
fi

cat > "$dest/INSTALL_INFO.txt" <<EOF
source   : $url
version  : ${version:-unknown}
installed: $(date '+%Y-%m-%d %H:%M:%S')
EOF

if [ "$KEEP_ARCHIVE" != "1" ]; then
    rm -f "$archive"
    rmdir "$cache_dir" 2>/dev/null || true
fi

printf '\nDone.\n'
printf '   LOVE    : %s\n' "$dest"
printf '   version : %s\n' "${version:-unknown}"
printf '   run     : Packager/play.sh\n'
printf '   check   : Packager/setup/install.sh --check\n'
