#!/bin/bash
set -e

# ── Usage ────────────────────────────────────────────────────────────────────
# Build all packages (in correct dependency order):
#   ./run-build.sh --all
#
# Build specific package(s):
#   ./run-build.sh capt-src
#   ./run-build.sh capt-src gtk2 libglade
#
# Packages are resolved from pkgbuilds/aur/<name> and pkgbuilds/repo/<name>.
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_FILE="${SCRIPT_DIR}/packages.txt"

if [[ ! -f "$PACKAGES_FILE" ]]; then
    echo "ERROR: Package file '$PACKAGES_FILE' not found." >&2
    exit 1
fi

# Ordered list of all packages read from packages.txt.
mapfile -t ALL_PACKAGES < <(grep -v -E '^\s*(#|$)' "$PACKAGES_FILE")

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 [--all | <pkg_name> [<pkg_name> ...]]"
    echo ""
    echo "  --all            Build every package in pkgbuilds/ (dependency-ordered)"
    echo "  <pkg_name>       Build only the specified package(s)"
    exit 1
fi

# Resolve --all to the ordered package list
if [[ "$1" == "--all" ]]; then
    set -- "${ALL_PACKAGES[@]}"
fi

PRIMARY_KEY_ID="${GPGKEY:-063F6A5182A1B15D}"
SIGNING_SUBKEY_ID="${GPG_SUBKEY:-46B2F45507CA0D4C}"

export GPGKEY="$PRIMARY_KEY_ID"

if [[ -z "${GPGKEY_PRIVATE_BASE64:-}" || -z "${GPGKEY_PASSPHRASE:-}" ]]; then
    echo "Primary GPG key ID: $PRIMARY_KEY_ID"
    echo "Signing subkey ID: $SIGNING_SUBKEY_ID"
    read -s -r -p "Enter passphrase for CI subkey $SIGNING_SUBKEY_ID: " GPGKEY_PASSPHRASE
    echo

    GPGKEY_PRIVATE_BASE64=$(gpg --batch \
        --pinentry-mode loopback \
        --passphrase "$GPGKEY_PASSPHRASE" \
        --export-secret-subkeys \
        --armor "$SIGNING_SUBKEY_ID"! \
        | base64 -w0)
    export GPGKEY_PRIVATE_BASE64
    export GPGKEY_PASSPHRASE
fi

podman build --build-arg GPGKEY="$GPGKEY" -t aur-builder .
podman run --rm --userns=keep-id \
    -e GPGKEY="$GPGKEY" \
    -e GPGKEY_PRIVATE_BASE64="$GPGKEY_PRIVATE_BASE64" \
    -e GPGKEY_PASSPHRASE="$GPGKEY_PASSPHRASE" \
    -v "$PWD/x86_64:/repo/x86_64:Z" \
    aur-builder "$@"

git add x86_64
if git diff --staged --quiet; then
    echo "No changes to commit"
else
    if [[ -n "${CI:-}" ]] && ! git config user.name >/dev/null 2>&1; then
        git config user.name "github-actions[bot]"
        git config user.email "github-actions[bot]@users.noreply.github.com"
    fi
    git commit -m "Update repo $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo ""
    echo "==> Pushing to GitHub..."
    git push
    echo "Done!"
fi
