#!/usr/bin/env bash
set -euo pipefail

git submodule foreach --recursive '
    git fetch origin --quiet

    if ! git remote set-head origin --auto >/dev/null 2>&1; then
        printf "%s: cannot detect upstream default branch\n" "$displaypath"
        exit 0
    fi

    upstream=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD) || exit 0
    count=$(git rev-list --count "HEAD..$upstream")

    if [ "$count" -gt 0 ]; then
        printf "\n%s: %s new commit(s)\n" "$displaypath" "$count"
        git log --oneline "HEAD..$upstream"
    else
        printf "%s: up to date\n" "$displaypath"
    fi
'
