#!/bin/bash
set -euo pipefail

ENV_FILE=".env"
PUB_GPG_FILE="doudou-aur.gpg"

# Check public GPG file exists
if [[ ! -f "$PUB_GPG_FILE" ]]; then
    echo "ERROR: Public GPG file '$PUB_GPG_FILE' not found."
    exit 1
fi

# Abort if .env already exists (optional: overwrite if needed)
if [[ -f "$ENV_FILE" ]]; then
    rm "$ENV_FILE"
fi

# Extract key ID from the public GPG file
GPG_KEY_ID=$(gpg --with-colons --import-options show-only --import "$PUB_GPG_FILE" \
        | awk -F: '/^pub/ {print $5}')

if [[ -z "$GPG_KEY_ID" ]]; then
    echo "ERROR: Failed to extract GPG key ID from '$PUB_GPG_FILE'."
    exit 1
fi

echo "Using GPG key ID: $GPG_KEY_ID"

# Export private key from local GPG keyring (must exist)
if ! gpg --list-secret-keys "$GPG_KEY_ID" >/dev/null 2>&1; then
    echo "ERROR: Private key for $GPG_KEY_ID not found in your local GPG keyring."
    exit 1
fi

# Export the private key in ASCII-armored format and base64 it
REPO_GPG_PRIVATE_BASE64=$(gpg --export-secret-keys --armor "$GPG_KEY_ID" | base64 -w0)

# Write to .env
cat > "$ENV_FILE" <<EOF
REPO_GPG_KEY_ID=$GPG_KEY_ID
REPO_GPG_PRIVATE_BASE64=$REPO_GPG_PRIVATE_BASE64
EOF

echo "$ENV_FILE generated successfully from public GPG '$PUB_GPG_FILE' and local private key."
