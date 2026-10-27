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

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
packages_file="${script_dir}/packages.txt"

if [[ -f "$packages_file" ]]; then
    if ! grep -qFx "$name" "$packages_file"; then
        echo "$name" >> "$packages_file"
        printf 'Appended %s to %s\n' "$name" "$packages_file"
    else
        printf '%s is already present in %s\n' "$name" "$packages_file"
    fi
fi
