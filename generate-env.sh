#!/bin/bash
set -euo pipefail

ENV_FILE=".env"
PRIMARY_KEY_ID="063F6A5182A1B15D"
SIGNING_SUBKEY_ID="46B2F45507CA0D4C"

echo "Primary GPG key ID: $PRIMARY_KEY_ID"
echo "Signing subkey ID: $SIGNING_SUBKEY_ID"

REPO_GPG_PRIVATE_BASE64=$(gpg --export-secret-subkeys --armor "$SIGNING_SUBKEY_ID"! | base64 -w0)

# Write to .env
cat > "$ENV_FILE" <<EOF
GPGKEY=$PRIMARY_KEY_ID
GPGKEY_PRIVATE_BASE64=$REPO_GPG_PRIVATE_BASE64
EOF

echo "$ENV_FILE generated successfully from public GPG '$PRIMARY_KEY_ID' and private key '$SIGNING_SUBKEY_ID'."
