#!/usr/bin/env bash
set -euo pipefail

PRIMARY_KEY_ID="${GPGKEY:-063F6A5182A1B15D}"
SIGNING_SUBKEY_ID="${GPG_SUBKEY:-46B2F45507CA0D4C}"

echo "================================================================================"
echo "  Generate GPG Secrets for GitHub Actions"
echo "  Primary Key ID:  $PRIMARY_KEY_ID"
echo "  Signing Subkey:  $SIGNING_SUBKEY_ID"
echo "================================================================================"
echo ""

read -s -r -p "Enter passphrase for CI subkey $SIGNING_SUBKEY_ID: " GPGKEY_PASSPHRASE
echo ""

echo "==> Exporting signing subkey using loopback pinentry..."
GPGKEY_PRIVATE_BASE64=$(gpg --batch \
    --pinentry-mode loopback \
    --passphrase "$GPGKEY_PASSPHRASE" \
    --export-secret-subkeys \
    --armor "$SIGNING_SUBKEY_ID"! \
    | base64 -w0)

echo ""
echo "================================================================================"
echo "  GitHub Actions Configuration"
echo "  Navigate to: Repo -> Settings -> Secrets and variables -> Actions"
echo "================================================================================"
echo ""
echo "▶ Secrets to add under 'Repository secrets':"
echo ""
echo "1. Name:  GPGKEY_PRIVATE_BASE64"
echo "   Value:"
echo "$GPGKEY_PRIVATE_BASE64"
echo ""
echo "--------------------------------------------------------------------------------"
echo "2. Name:  GPGKEY_PASSPHRASE"
echo "   Value: <The passphrase you entered above>"
echo ""
echo "--------------------------------------------------------------------------------"
echo "▶ Variable or Secret (Optional - already defaulted in build workflow):"
echo "   Name:  GPGKEY"
echo "   Value: $PRIMARY_KEY_ID"
echo "================================================================================"
