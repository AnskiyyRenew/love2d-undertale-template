#!/bin/sh
# Packager/setup/bootstrap.sh -- clone this repository and install LOVE, for a
# machine that has neither (a fresh VM, for example). Standalone: it does not
# read setup.conf and does not need to sit inside a checkout.
#
#   sh bootstrap.sh                    clone into ./love2d-undertale-template
#   sh bootstrap.sh --dir ~/dev/se     clone somewhere else
#   sh bootstrap.sh --update           pull --ff-only in an existing clone
#   sh bootstrap.sh --zip              snapshot download, works without git
#   sh bootstrap.sh --full             full history instead of --depth 1
#   sh bootstrap.sh --skip-love        clone only
#   sh bootstrap.sh --force            reinstall LOVE even if present
#   sh bootstrap.sh --check            environment report of the clone
#
# The clone is shallow by default: the tracked tree is about 140 MB and the
# full history is roughly twice that, which nobody needs inside a test VM.

set -eu

REPO=https://github.com/AnskiyyRenew/love2d-undertale-template.git
BRANCH=main
DIR=""
UPDATE=0
FULL=0
ZIP=0
SKIP_LOVE=0
FORCE=0
CHECK=0

usage() {
    sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
    case "$1" in
        -d|--dir) shift; DIR=${1:-} ;;
        -b|--branch) shift; BRANCH=${1:-} ;;
        -r|--repo) shift; REPO=${1:-} ;;
        -u|--update) UPDATE=1 ;;
        -f|--full) FULL=1 ;;
        -z|--zip) ZIP=1 ;;
        -s|--skip-love) SKIP_LOVE=1 ;;
        -F|--force) FORCE=1 ;;
        -c|--check) CHECK=1 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

fetch() {   # $1 url, $2 out
    rm -f "$2"
    if command -v curl >/dev/null 2>&1; then
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
    elif command -v bsdtar >/dev/null 2>&1; then
        bsdtar -xf "$1" -C "$2"
    elif command -v python3 >/dev/null 2>&1; then
        python3 -m zipfile -e "$1" "$2"
    else
        printf '[error] no unzip, bsdtar or python3 available to extract %s\n' "$1" >&2
        return 1
    fi
}

name=$(basename "$REPO" .git)
[ -n "$DIR" ] || DIR=$(pwd)/$name
target=$DIR

use_git=1
command -v git >/dev/null 2>&1 || use_git=0
if [ "$ZIP" -eq 1 ]; then use_git=0; fi

printf 'SoulEngine - repository bootstrap\n'
printf '\n== Target\n'
printf '   repo   : %s\n' "$REPO"
printf '   branch : %s\n' "$BRANCH"
printf '   dir    : %s\n' "$target"
if [ "$use_git" -eq 1 ]; then
    printf '   method : git clone%s\n' "$([ "$FULL" -eq 1 ] || printf ' (depth 1)')"
else
    printf '   method : zip snapshot\n'
fi

if [ -f "$target/conf.lua" ] && [ "$UPDATE" -eq 1 ]; then
    printf '\n== Updating existing clone\n'
    if [ "$use_git" -eq 0 ]; then
        printf '   [error] git is not usable here, so this folder cannot be updated\n' >&2
        printf '           delete it and re-run without --update\n' >&2
        exit 1
    fi
    if [ ! -d "$target/.git" ]; then
        printf '   [error] this folder is not a git checkout (zip snapshot)\n' >&2
        printf '           re-run with --zip to refresh it, or delete it and clone normally\n' >&2
        exit 1
    fi
    git -C "$target" pull --ff-only
elif [ -f "$target/conf.lua" ]; then
    printf '\n   already cloned - skipping the download (use --update to pull)\n'
else
    if [ -e "$target" ] && [ -n "$(ls -A "$target" 2>/dev/null)" ]; then
        printf '   [error] target folder is not empty: %s\n' "$target" >&2
        printf '           pick another --dir, or empty that folder first\n' >&2
        exit 1
    fi

    if [ "$use_git" -eq 1 ]; then
        printf '\n== Cloning\n'
        if [ "$FULL" -eq 1 ]; then
            git clone --branch "$BRANCH" "$REPO" "$target"
        else
            git clone --depth 1 --branch "$BRANCH" "$REPO" "$target"
        fi
    else
        if [ "$ZIP" -eq 0 ]; then
            printf '\n   [warn] git is not installed - falling back to a zip snapshot\n'
            printf '          Debian/Ubuntu: sudo apt install git\n'
            printf '          Fedora:        sudo dnf install git\n'
            printf '          macOS:         xcode-select --install\n'
            printf '          a snapshot cannot be updated with --update; re-run --zip to refresh\n'
        fi

        slug=$(printf '%s' "$REPO" | sed -n 's|^https://github\.com/\(.*\)\.git$|\1|p')
        if [ -z "$slug" ]; then
            printf '   [error] the zip fallback only understands github.com URLs\n' >&2
            printf '           install git instead, or pass --repo with a github.com URL\n' >&2
            exit 1
        fi

        printf '\n== Downloading snapshot\n'
        zipurl="https://codeload.github.com/$slug/zip/refs/heads/$BRANCH"
        printf '   url : %s\n' "$zipurl"

        work=$(mktemp -d "${TMPDIR:-/tmp}/se-repo.XXXXXX")
        trap 'rm -rf "$work"' EXIT INT TERM
        fetch "$zipurl" "$work/repo.zip"
        printf '   saved %s MB\n' "$(du -m "$work/repo.zip" 2>/dev/null | cut -f1)"

        printf '\n== Extracting\n'
        unzip_into "$work/repo.zip" "$work/x"
        root=$(find "$work/x" -maxdepth 1 -mindepth 1 -type d | head -n 1)
        if [ -z "$root" ]; then
            printf '   [error] the snapshot contains no folder\n' >&2
            exit 1
        fi
        mkdir -p "$target"
        cp -R "$root"/. "$target"/
    fi
fi

printf '\n== Checking the checkout\n'
if [ ! -f "$target/conf.lua" ]; then
    printf '   [error] conf.lua is missing in %s\n' "$target" >&2
    printf '           the clone looks incomplete - delete the folder and try again\n' >&2
    exit 1
fi
printf '   conf.lua found - this is a SoulEngine checkout\n'

installer=$target/Packager/setup/install.sh
if [ "$SKIP_LOVE" -eq 1 ]; then
    printf '   LOVE install skipped (--skip-love)\n'
elif [ ! -f "$installer" ]; then
    printf '   [warn] Packager/setup/install.sh not found in the checkout - skipping LOVE\n'
else
    printf '\n== Installing LOVE\n'
    if [ "$FORCE" -eq 1 ] && [ "$CHECK" -eq 1 ]; then
        sh "$installer" --force --check
    elif [ "$FORCE" -eq 1 ]; then
        sh "$installer" --force
    elif [ "$CHECK" -eq 1 ]; then
        sh "$installer" --check
    else
        sh "$installer"
    fi
fi

printf '\nDone.\n'
printf '   repo : %s\n' "$target"
printf '   run  : cd "%s" && ./Packager/play.sh\n' "$target"
printf '   env  : sh "%s/Packager/setup/install.sh" --check\n' "$target"
if [ "$use_git" -eq 0 ]; then
    printf '   note : zip snapshot - no git history and no --update\n'
fi
