#!/bin/bash
set -euo pipefail

REPO_DIR="/repo/x86_64"
REPO_DB="${REPO_DIR}/doudou-aur.db.tar.gz"
PKGBUILDS_DIR="/repo/pkgbuilds"

# ── helpers ──────────────────────────────────────────────────────────────────

usage() {
    echo "Usage: build.sh <pkg_name> [<pkg_name> ...]"
    echo ""
    echo "  <pkg_name>       Build the specified package(s) in order"
    echo ""
    echo "Packages are discovered from pkgbuilds/aur/ and pkgbuilds/repo/."
    exit 1
}

# Ensure the repo database exists
init_repo() {
    if [[ ! -f "$REPO_DB" ]]; then
        echo "==> Initialising empty repository database..."
        repo-add -s -k "$GPGKEY" "$REPO_DB"
    fi
    sudo pacman -Sy --noconfirm
}

# Find the PKGBUILD directory for a given package name.
# Searches pkgbuilds/aur/<name> and pkgbuilds/repo/<name>.
find_pkg_dir() {
    local name="$1"
    for prefix in "${PKGBUILDS_DIR}/aur" "${PKGBUILDS_DIR}/repo"; do
        if [[ -f "${prefix}/${name}/PKGBUILD" ]]; then
            echo "${prefix}/${name}"
            return 0
        fi
    done
    echo "ERROR: No PKGBUILD found for '${name}'" >&2
    return 1
}

# Build a single package from its PKGBUILD directory.
# - Installs missing dependencies from the repo and official repos
# - Builds with makepkg, signs the package
# - Adds to the repo database with --remove to clean old versions
build_pkg() {
    local pkg_dir="$1"
    local pkg_name
    pkg_name=$(basename "$pkg_dir")

    echo ""
    echo "══════════════════════════════════════════════════════════════"
    echo "  Building: ${pkg_name}"
    echo "══════════════════════════════════════════════════════════════"

    # Work in a copy so the submodule stays clean
    local work_dir="/tmp/build-${pkg_name}"
    rm -rf "$work_dir"
    cp -a "$pkg_dir" "$work_dir"
    cd "$work_dir"

    # Install dependencies (from official repos + our local repo)
    makepkg --syncdeps --noconfirm --sign \
            --key "$GPGKEY" \
            --config /etc/makepkg.conf \
            2>&1 | tee "/tmp/build-${pkg_name}.log"

    # Find built package(s) and add to repo
    local pkg_files
    pkg_files=(*.pkg.tar.zst)
    if [[ ${#pkg_files[@]} -eq 0 ]]; then
        echo "ERROR: No packages built for ${pkg_name}" >&2
        return 1
    fi

    for pkg_file in "${pkg_files[@]}"; do
        echo "==> Adding ${pkg_file} to repository..."
        cp "$pkg_file" "$REPO_DIR/"
        cp "${pkg_file}.sig" "$REPO_DIR/" 2>/dev/null || true

        # --remove (-R) deletes old version files from disk automatically
        repo-add -s -R -k "$GPGKEY" "$REPO_DB" "${REPO_DIR}/${pkg_file}"
    done

    # Refresh pacman DB so subsequent builds can find this package as a dependency
    sudo pacman -Sy --noconfirm

    echo "==> ${pkg_name} done."
    cd /
    rm -rf "$work_dir"
}

# ── main ─────────────────────────────────────────────────────────────────────

if [[ $# -eq 0 ]]; then
    usage
fi

# Set GPG signing command for repo-add / makepkg
export GPGKEY
export GPG="gpg --batch --yes --pinentry-mode loopback --passphrase ${GPGKEY_PASSPHRASE}"

init_repo

for pkg_name in "$@"; do
    pkg_dir=$(find_pkg_dir "$pkg_name")
    build_pkg "$pkg_dir"
done

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Build complete. Repository is ready in x86_64/"
echo "════════════════════════════════════════════════════════════════"
