#!/usr/bin/env bash
set -euo pipefail
if [[ -z "${CF_ACCOUNT_ID:-}" ]]; then
  echo '::error::CF_ACCOUNT_ID is missing; cannot verify automatic deployment.'
  exit 1
fi
current_commit="$(git rev-parse HEAD)"
latest_run="$(gh run list --repo "$GITHUB_REPOSITORY" --workflow deploy.yml --commit "$current_commit" --limit 1 --json databaseId,status,conclusion)"
run_id="$(jq -r '.[0].databaseId // empty' <<< "$latest_run")"
status="$(jq -r '.[0].status // empty' <<< "$latest_run")"
conclusion="$(jq -r '.[0].conclusion // empty' <<< "$latest_run")"
if [[ "$conclusion" == success ]]; then
  echo "Current main $current_commit is already deployed."
elif [[ -n "$run_id" && "$status" != completed ]]; then
  gh run watch "$run_id" --repo "$GITHUB_REPOSITORY" --exit-status --interval 10
else
  # GITHUB_TOKEN pushes do not start push workflows: dispatch explicitly.
  started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  gh workflow run deploy.yml --repo "$GITHUB_REPOSITORY" --ref main
  run_id=''
  for attempt in {1..12}; do
    runs="$(gh run list --repo "$GITHUB_REPOSITORY" --workflow deploy.yml --commit "$current_commit" --event workflow_dispatch --limit 10 --json databaseId,createdAt)"
    run_id="$(jq -r --arg since "$started_at" '[.[] | select(.createdAt >= $since)] | first | .databaseId // empty' <<< "$runs")"
    [[ -n "$run_id" ]] && break
    sleep 5
  done
  [[ -n "$run_id" ]] || { echo '::error::Could not find dispatched deployment.'; exit 1; }
  gh run watch "$run_id" --repo "$GITHUB_REPOSITORY" --exit-status --interval 10
fi
expected="$(jq -r '.workers' version.json)"
for attempt in {1..12}; do
  actual="$(curl --fail --silent --show-error --max-time 20 https://tz.onemjj.com/api/config | jq -r '.version')" || actual='unavailable'
  if [[ "$actual" == "$expected" ]]; then
    echo "Verified live version: $actual" >> "${GITHUB_STEP_SUMMARY:-/dev/stdout}"
    exit 0
  fi
  sleep 10
done
echo "::error::Live version $actual does not match expected $expected."
exit 1
