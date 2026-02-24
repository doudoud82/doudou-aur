#!/bin/bash
set -e

ENV_FILE=".env"

rm -f "$ENV_FILE"
./generate-env.sh
if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: $ENV_FILE not generated"
    exit 1
fi
# shellcheck source=/dev/null
source "$ENV_FILE"

docker build --build-arg GPGKEY="$GPGKEY" -t aur-builder docker/

docker run --rm \
    --name aur-builder \
    --env-file "$ENV_FILE" \
    -v "$PWD:/repo" \
    aur-builder

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
