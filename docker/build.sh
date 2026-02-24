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
export AUR_PAGER=cat
# Temporary downgrade gawk to 5.3.2 because of error until it get fixed
# https://github.com/aurutils/aurutils/issues/1245
# gawk: /usr/lib/aurutils/aur-graph:72:     delete(arch)
# gawk: /usr/lib/aurutils/aur-graph:72:           ^ syntax error

sudo pacman -U https://archive.archlinux.org/packages/g/gawk/gawk-5.3.2-1-x86_64.pkg.tar.zst --noconfirm

packages_aur=$(grep -v '^\s*#' "$PKG_LIST" | grep -v '^\s*$' | tr '\n' ' ')
for dir in "$PKG_DIR"/*/; do
    if [[ -f "${dir}PKGBUILD" ]]; then
        printf '%s\n' "${dir%/}" >> /tmp/pkgbuild_paths
    fi
done
aur sync --noview --sign --upgrades --noconfirm  $packages_aur
aur build --sign --remove --new -a /tmp/pkgbuild_paths
echo "Build complete. Repo is ready in x86_64."
