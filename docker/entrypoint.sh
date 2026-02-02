#!/bin/bash
set -euo pipefail

# Check GPG key is provided
if [[ -z "${REPO_GPG_PRIVATE_BASE64:-}" ]]; then
    echo "ERROR: REPO_GPG_PRIVATE_BASE64 environment variable is not set."
    exit 1
fi

# Import GPG private key for signing
echo "$REPO_GPG_PRIVATE_BASE64" | base64 -d | gpg --batch --import

# Pass execution to the build script
GPGKEY=$REPO_GPG_KEY_ID exec /build.sh
