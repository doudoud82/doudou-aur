#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_FILE="${SCRIPT_DIR}/packages.txt"
PKGBUILDS_AUR_DIR="${SCRIPT_DIR}/pkgbuilds/aur"

ALL=0
NO_COMMIT=0
PUSH=0
REQUESTED_PACKAGES=()

usage() {
    cat <<EOF
Usage: $(basename "$0") [--all | <pkg_name> [<pkg_name> ...]] [options]

Updates AUR submodule packages to their latest upstream commit and pins
(fixes) the new commit hash in this repository.

Options:
  --all          Check and update all AUR packages from packages.txt
  --no-commit    Update and stage submodules without committing
  --push         Push changes to remote git repository after committing
  -h, --help     Show this help message

Arguments:
  <pkg_name>     One or more AUR package names to check and update

Examples:
  $(basename "$0") --all                         # Check and update all AUR packages
  $(basename "$0") capt-src gtk2                 # Update only capt-src and gtk2
  $(basename "$0") --all --push                  # Update all AUR packages and push
  $(basename "$0") --no-commit ab-download-manager-bin
EOF
}

# If no arguments provided, show usage similar to run-build.sh
if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

# Parse options and arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)
            ALL=1
            shift
            ;;
        --no-commit)
            NO_COMMIT=1
            shift
            ;;
        --push)
            PUSH=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "Error: Unknown option '$1'" >&2
            echo "Use --help for usage information." >&2
            exit 1
            ;;
        *)
            # Clean argument in case user passed "pkgbuilds/aur/name" or trailing slash
            pkg="$1"
            pkg="${pkg%/}"
            pkg="${pkg##*/}"
            REQUESTED_PACKAGES+=("$pkg")
            shift
            ;;
    esac
done

if [[ "$ALL" -eq 0 && ${#REQUESTED_PACKAGES[@]} -eq 0 ]]; then
    usage
    exit 1
fi

# Determine list of packages to process
PACKAGES_TO_CHECK=()

if [[ "$ALL" -eq 1 ]]; then
    if [[ ! -f "$PACKAGES_FILE" ]]; then
        echo "Error: Package file '$PACKAGES_FILE' not found." >&2
        exit 1
    fi

    # Read all packages from packages.txt (ordered list)
    mapfile -t ALL_PACKAGES < <(grep -v -E '^\s*(#|$)' "$PACKAGES_FILE")

    for pkg in "${ALL_PACKAGES[@]}"; do
        # Strip potential leading/trailing whitespace
        pkg=$(echo "$pkg" | xargs)
        [[ -z "$pkg" ]] && continue

        if [[ -d "${PKGBUILDS_AUR_DIR}/${pkg}" ]]; then
            PACKAGES_TO_CHECK+=("$pkg")
        elif [[ -d "${SCRIPT_DIR}/pkgbuilds/repo/${pkg}" ]]; then
            echo "Skipping '${pkg}': located in pkgbuilds/repo/ (local repo package, not an AUR submodule)"
        else
            echo "Warning: Package '${pkg}' in packages.txt not found in ${PKGBUILDS_AUR_DIR}" >&2
        fi
    done
else
    for pkg in "${REQUESTED_PACKAGES[@]}"; do
        if [[ -d "${PKGBUILDS_AUR_DIR}/${pkg}" ]]; then
            PACKAGES_TO_CHECK+=("$pkg")
        elif [[ -d "${SCRIPT_DIR}/pkgbuilds/repo/${pkg}" ]]; then
            echo "Skipping '${pkg}': located in pkgbuilds/repo/ (local repo package, not an AUR submodule)"
        else
            echo "Error: Package '${pkg}' not found in ${PKGBUILDS_AUR_DIR}" >&2
            exit 1
        fi
    done
fi

if [[ ${#PACKAGES_TO_CHECK[@]} -eq 0 ]]; then
    echo "No AUR packages to check."
    exit 0
fi

echo "Checking ${#PACKAGES_TO_CHECK[@]} AUR package(s) for upstream updates..."

UPDATED_PACKAGES=()
DETAILS=()

for pkg in "${PACKAGES_TO_CHECK[@]}"; do
    pkg_path="pkgbuilds/aur/${pkg}"
    full_path="${SCRIPT_DIR}/${pkg_path}"

    # Ensure submodule git directory exists / initialized
    if [[ ! -e "${full_path}/.git" ]]; then
        echo "Initializing submodule ${pkg_path}..."
        git submodule update --init "${pkg_path}"
    fi

    current_hash=$(git -C "$full_path" rev-parse HEAD 2>/dev/null || echo "")
    if [[ -z "$current_hash" ]]; then
        echo "Warning: Unable to determine HEAD commit for ${pkg}, skipping." >&2
        continue
    fi

    # Fetch latest upstream commits
    git -C "$full_path" fetch origin --quiet

    # Determine default branch (e.g. master or main)
    git -C "$full_path" remote set-head origin --auto >/dev/null 2>&1 || true
    upstream=$(git -C "$full_path" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)
    if [[ -z "$upstream" ]]; then
        for candidate in origin/master origin/main; do
            if git -C "$full_path" rev-parse --verify "$candidate" >/dev/null 2>&1; then
                upstream="$candidate"
                break
            fi
        done
    fi

    if [[ -z "$upstream" ]]; then
        echo "Warning: Could not determine upstream branch for ${pkg}, skipping." >&2
        continue
    fi

    upstream_hash=$(git -C "$full_path" rev-parse "$upstream")
    count=$(git -C "$full_path" rev-list --count "HEAD..$upstream" 2>/dev/null || echo 0)

    if [[ "$count" -gt 0 || "$current_hash" != "$upstream_hash" ]]; then
        echo ""
        echo "------------------------------------------------------------"
        echo "Found update for: ${pkg} (${count} new commit(s))"
        echo "Current:  ${current_hash:0:8}"
        echo "Upstream: ${upstream_hash:0:8} (${upstream})"
        echo "------------------------------------------------------------"
        git -C "$full_path" log --oneline "HEAD..$upstream"

        # Check out the exact upstream commit so HEAD points to the fixed hash
        git -C "$full_path" checkout --quiet --detach "$upstream_hash"

        # Stage the updated submodule reference in the main repository
        git -C "$SCRIPT_DIR" add "$pkg_path"

        # Extract new pkgver-pkgrel if available from PKGBUILD
        pkg_ver=""
        if [[ -f "${full_path}/PKGBUILD" ]]; then
            pkgver=$(grep -E '^\s*pkgver=' "${full_path}/PKGBUILD" | head -n1 | cut -d= -f2- | tr -d "'\"[:space:]")
            pkgrel=$(grep -E '^\s*pkgrel=' "${full_path}/PKGBUILD" | head -n1 | cut -d= -f2- | tr -d "'\"[:space:]")
            if [[ -n "$pkgver" ]]; then
                pkg_ver="${pkgver}-${pkgrel}"
            fi
        fi

        UPDATED_PACKAGES+=("$pkg")
        if [[ -n "$pkg_ver" ]]; then
            DETAILS+=("${pkg} (${pkg_ver})")
        else
            DETAILS+=("${pkg} (${upstream_hash:0:8})")
        fi
        echo "✓ Fixed submodule ${pkg} to commit ${upstream_hash:0:8}"
    else
        echo "${pkg}: up to date (${current_hash:0:8})"
    fi
done

echo ""
if [[ ${#UPDATED_PACKAGES[@]} -eq 0 ]]; then
    echo "All checked packages are up to date. Nothing to update."
else
    echo "============================================================"
    echo "Updated ${#UPDATED_PACKAGES[@]} package(s): ${UPDATED_PACKAGES[*]}"
    echo "============================================================"

    if [[ "$NO_COMMIT" -eq 0 ]]; then
        # Check if there are staged changes to commit
        if ! git -C "$SCRIPT_DIR" diff --staged --quiet; then
            if [[ -n "${CI:-}" ]] && ! git config user.name >/dev/null 2>&1; then
                git config user.name "github-actions[bot]"
                git config user.email "github-actions[bot]@users.noreply.github.com"
            fi

            if [[ ${#UPDATED_PACKAGES[@]} -eq 1 ]]; then
                commit_msg="Update ${DETAILS[0]}"
            else
                commit_msg="Update AUR packages: $(IFS=', '; echo "${DETAILS[*]}")"
            fi

            git -C "$SCRIPT_DIR" commit -m "$commit_msg"
            echo "Committed update: $commit_msg"

            if [[ "$PUSH" -eq 1 ]]; then
                echo "Pushing changes to remote..."
                git -C "$SCRIPT_DIR" push
                echo "Push complete."
            fi
        fi
    else
        echo "(--no-commit specified: changes are staged but not committed)"
    fi
fi

# Export outputs for GitHub Actions if running inside a workflow
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    {
        echo "updated_packages=${UPDATED_PACKAGES[*]}"
        echo "has_updates=$([[ ${#UPDATED_PACKAGES[@]} -gt 0 ]] && echo 'true' || echo 'false')"
        echo "count=${#UPDATED_PACKAGES[@]}"
    } >> "$GITHUB_OUTPUT"
fi
