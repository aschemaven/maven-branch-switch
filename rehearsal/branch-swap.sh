#!/usr/bin/env bash
# Branch swap for maven-sources#57: master (Maven 4) <-> <repo>-3.x (Maven 3).
# Rename-based: GitHub auto-retargets open PRs to the renamed base (no force-push,
# merge bases preserved). Rehearsed on aschemaven/maven-sources-57-rehearsal 2026-10-06.
# On the real apache/* repos the two renames are performed by INFRA (protected master);
# the default_branch + protection go through .asf.yaml.
set -euo pipefail
ORG=${1:?org}; REPO=${2:?repo}; B="repos/$ORG/$REPO"

# 1. master (Maven 4) -> <repo>-4.x. Retargets open PRs onto the Maven 4 line;
#    GitHub moves default_branch to the new name.
gh api -X POST "$B/branches/master/rename" -f new_name="$REPO-4.x" --jq .name

# 2. <repo>-3.x (Maven 3) -> master. After a default-branch rename GitHub may briefly
#    still hold `master` -> 422 "already exists". Clear the stray ref, then retry.
if ! gh api -X POST "$B/branches/$REPO-3.x/rename" -f new_name=master --jq .name 2>/dev/null; then
  gh api -X DELETE "$B/git/refs/heads/master" 2>/dev/null || true
  sleep 2
  gh api -X POST "$B/branches/$REPO-3.x/rename" -f new_name=master --jq .name
fi

# 3. default_branch back to master (real repos: github.default_branch in .asf.yaml).
gh api -X PATCH "$B" -f default_branch=master --jq .default_branch

gh api "$B/branches" --jq '"branches: "+([.[].name]|join(", "))'
