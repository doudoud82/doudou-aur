#!/bin/bash
set -euo pipefail

# Check GPG key is provided
if [[ -z "${GPGKEY_PRIVATE_BASE64:-}" ]]; then
    echo "ERROR: REPO_GPG_PRIVATE_BASE64 environment variable is not set."
    exit 1
fi

# Import GPG private key for signing
echo "$GPGKEY_PRIVATE_BASE64" | base64 -d | gpg --batch --import

gpg --batch --yes --pinentry-mode loopback --passphrase "$GPGKEY_PASSPHRASE" --export-secret-keys >/dev/null

# Pass execution to the build script
exec /build.sh
