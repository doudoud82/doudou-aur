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

ENV_FILE=".env"

./generate-env.sh
if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: $ENV_FILE not generated"
    exit 1
fi
# shellcheck source=/dev/null
source "$ENV_FILE"

podman build --build-arg GPGKEY="$GPGKEY" -t aur-builder .
podman run --rm --userns=keep-id --env-file "$ENV_FILE" -v "$PWD/x86_64:/repo/x86_64:Z" aur-builder "$@"

rm -f "$ENV_FILE"

git add x86_64
if git diff --staged --quiet; then
    echo "No changes to commit"
else
    git commit -m "Update repo $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo ""
    echo "==> Pushing to GitHub..."
    git push
    echo "Done!"
fi
