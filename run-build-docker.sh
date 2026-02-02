#!/bin/bash
set -e

ENV_FILE=".env"

# Generate .env from doudou-aur.gpg
./generate-env.sh

docker build -t aur-builder docker/

docker run --rm \
    --name aur-builder \
    --env-file "$ENV_FILE" \
    -v "$PWD:/repo" \
    aur-builder


git add .
if git diff --staged --quiet; then
    echo "No changes to commit"
else
    git commit -m "Update repo $(date -u '+%Y-%m-%d %H:%M')"
    echo ""
    echo "==> Pushing to GitHub..."
    git push
    echo "Done!"
fi
