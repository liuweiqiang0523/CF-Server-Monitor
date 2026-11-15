#!/usr/bin/env bash
# Prepare a merge only; the workflow validates it before publishing.
set -euo pipefail
upstream_url="${UPSTREAM_URL:-https://github.com/huilang-me/CF-Server-Monitor.git}"
git fetch --no-tags "$upstream_url" "${UPSTREAM_BRANCH:-main}"
upstream_commit="$(git rev-parse FETCH_HEAD)"
if git merge-base --is-ancestor "$upstream_commit" HEAD; then
  echo "changed=false" >> "${GITHUB_OUTPUT:-/dev/stdout}"
  echo "Fork already contains upstream $upstream_commit."
  exit 0
fi
if git merge-base --is-ancestor HEAD "$upstream_commit"; then
  git merge --ff-only "$upstream_commit"
elif ! git merge --no-edit --no-ff "$upstream_commit"; then
  conflicts="$(git diff --name-only --diff-filter=U)"
  git merge --abort
  echo "::error title=Upstream sync conflict::Resolve these files manually: $conflicts"
  exit 1
fi
echo "changed=true" >> "${GITHUB_OUTPUT:-/dev/stdout}"
echo "Prepared upstream $upstream_commit; validation is required before push."
