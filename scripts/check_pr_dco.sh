#!/usr/bin/env bash
# PR DCO：只检查事件中的 base..head，保留所有真实提交（含 merge）。
# Check the event's exact base..head range, including real merge commits.
# 官方 Dependabot 需 gh、GITHUB_REPOSITORY 和只读 GitHub API 访问；其余提交离线检查。
# Official Dependabot requires gh, GITHUB_REPOSITORY and read-only GitHub API access.
set -euo pipefail

fail() { echo "::error::$*" >&2; exit 1; }

validate_commit() {
  local name="$1" sha="$2" type
  [[ "$sha" =~ ^([0-9a-f]{40}|[0-9a-f]{64})$ ]] ||
    fail "$name must be a full commit SHA"
  type="$(git cat-file -t "$sha")" || fail "$name commit object is unavailable"
  [[ "$type" == commit ]] || fail "$name must identify a commit object"
}

# Dependabot signs with support@github.com, not its Git author email.
# Accept that exact identity only when GitHub verifies this repository's SHA.
verified_dependabot() {
  local sha="$1" name="$2" email="$3" body="$4" verified_sha
  [[ "$name" == 'dependabot[bot]' &&
     "$email" == '49699333+dependabot[bot]@users.noreply.github.com' ]] || return 1
  grep -qxF 'Signed-off-by: dependabot[bot] <support@github.com>' <<< "$body" || return 1
  [[ "${GITHUB_REPOSITORY:-}" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || return 1
  verified_sha="$(gh api --hostname github.com "repos/$GITHUB_REPOSITORY/commits/$sha" --jq '
    if .author.login == "dependabot[bot]" and .author.type == "Bot"
      and .author.id == 49699333
      and .commit.author.name == "dependabot[bot]"
      and .commit.author.email == "49699333+dependabot[bot]@users.noreply.github.com"
      and .committer.login == "web-flow"
      and .commit.verification.verified == true
      and .commit.verification.reason == "valid"
    then .sha else "" end
  ')" || return 1
  [[ "$verified_sha" == "$sha" ]]
}

base="${PR_BASE_SHA:-}"
head="${PR_HEAD_SHA:-}"
validate_commit PR_BASE_SHA "$base"
validate_commit PR_HEAD_SHA "$head"

# Do not hide rev-list failure in process substitution: missing history must fail.
commits="$(git rev-list "$base..$head" --)" || fail "Cannot enumerate PR commits"
[[ -n "$commits" ]] || fail "PR range contains no commits"

rc=0
total=0
while IFS= read -r sha; do
  total=$((total + 1))
  name="$(git log -1 --format='%an' "$sha")" || fail "Cannot read author for $sha"
  email="$(git log -1 --format='%ae' "$sha")" || fail "Cannot read author for $sha"
  body="$(git log -1 --format='%b' "$sha")" || fail "Cannot read message for $sha"
  if [[ "$name" == 'dependabot[bot]' ||
        "$email" == '49699333+dependabot[bot]@users.noreply.github.com' ]]; then
    if ! verified_dependabot "$sha" "$name" "$email" "$body"; then
      echo "::error::commit ${sha:0:12}: Dependabot identity, signoff or GitHub verification is invalid"
      rc=1
    fi
    continue
  fi
  # Keep email matching literal: bot addresses may contain [ ] + . characters.
  if ! signoffs="$(grep -i '^signed-off-by:' <<< "$body")" ||
     ! grep -qiF -- "<${email}>" <<< "$signoffs"; then
    echo "::error::commit ${sha:0:12}: author <${email}> lacks a matching Signed-off-by"
    rc=1
  fi
done <<< "$commits"

[[ "$rc" -eq 0 ]] || exit "$rc"
echo "DCO passed for $total PR commits ($base..$head)"
