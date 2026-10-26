#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    printf 'Usage: %s <AUR URL>\n' "$0" >&2
    exit 1
fi

url=${1%/}
name=${url##*/}
name=${name%.git}
path="pkgbuilds/aur/$name"

git submodule add --force "$url" "$path"

# Get the exact commit recorded by the submodule.
hash=$(git -C "$path" rev-parse HEAD)

printf '\nAdded AUR submodule: %s\n' "$path"
printf 'Commit: %s\n' "$hash"
