#!/usr/bin/env bash
set -e

echo "==> Setting up GPG secrets..."
./setup-gpg-secrets.sh

echo "==> Building packages in container..."
docker compose down
docker compose up

echo ""
echo "==> Committing changes..."
git add x86_64/
if git diff --staged --quiet; then
    echo "No changes to commit"
else
    git commit -m "Update packages $(date -u '+%Y-%m-%d %H:%M')"
    echo ""
    echo "==> Pushing to GitHub..."
    git push
    echo "✓ Done!"
fi

echo ""
echo "✓ Done!"