#!/usr/bin/env bash
set -e

if [ ! -f doudou-aur.gpg ]; then
	GPG_KEY_ID="3E7914503C6B7242"
	gpg --armor --export "$GPG_KEY_ID" > doudou-aur.gpg
	git add doudou-aur.gpg
	git commit -m "added public gpg key: doudou-aur.gpg"
	git push
else
	echo "Extracting key ID from doudou-aur.gpg..."
	GPG_KEY_ID=$(gpg --show-keys --keyid-format=long doudou-aur.gpg | grep pub | awk '{print $2}' | cut -d'/' -f2)
fi

echo "$GPG_KEY_ID" > gpg_key_id.secret
echo "✓ Created gpg_key_id.secret"

echo "Exporting private key for: $GPG_KEY_ID"
gpg --armor --export-secret-keys "$GPG_KEY_ID" > gpg_private_key.secret
echo "✓ Created gpg_private_key.secret"