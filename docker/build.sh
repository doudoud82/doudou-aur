#!/bin/bash
set -euo pipefail

PKG_DIR="/repo/repo-pkgbuild"
PKG_LIST="/repo/packages"

if [[ ! -f "/repo/x86_64/doudou-aur.db.tar.gz" ]]; then
    repo-add -k "$GPGKEY" -s  "/repo/x86_64/doudou-aur.db.tar.gz"
fi

sudo pacman -Sy --noconfirm
mkdir -p "/repo/aur-PKGBUILD"
export AURDEST="/repo/aur-PKGBUILD"

packages_aur=$(grep -v '^\s*#' "$PKG_LIST" | grep -v '^\s*$' | tr '\n' ' ')
for dir in "$PKG_DIR"/*/; do
    if [[ -f "${dir}PKGBUILD" ]]; then
        printf '%s\n' "${dir%/}" >> /tmp/pkgbuild_paths
    fi
done
aur sync --noview --sign --upgrades --noconfirm  $packages_aur
aur build --sign --remove --new -a /tmp/pkgbuild_paths
echo "Build complete. Repo is ready in x86_64."
