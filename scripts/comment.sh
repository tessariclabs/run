#!/usr/bin/env bash
# The pull request comment: one per workspace and shard, found by its hidden marker and edited in
# place, never posted twice. `comment.sh running` marks a run in progress; `comment.sh final FILE`
# writes the body in FILE. Without permission to comment it says so once and leaves the step green.
set -euo pipefail

mode=$1
pr=$(jq -r '.pull_request.number // empty' "$GITHUB_EVENT_PATH" 2>/dev/null || true)
[ -n "$pr" ] || exit 0
marker="<!-- tessaric:run ${TESSARIC_KEY} -->"
repo=$GITHUB_REPOSITORY

existing=$(gh api --paginate "repos/$repo/issues/$pr/comments" \
  --jq ".[] | select(.body | contains(\"$marker\")) | \"\(.id)\t\(try (.body | capture(\"<!-- tessaric:last (?<s>[^>]*) -->\").s) catch \"\")\"" \
  2>/dev/null | head -n 1 || true)
id=${existing%%$'\t'*}
last=${existing#*$'\t'}
[ "$id" != "$existing" ] || last=""

body=$(mktemp)
if [ "$mode" = running ]; then
  {
    echo "$marker"
    printf '%s&nbsp; **verifying** `%s`' "$TESSARIC_BANNER" "${TESSARIC_SHA:0:7}"
    [ -z "$last" ] || printf ' · last: %s' "$last"
    echo
    [ -z "$last" ] || echo "<!-- tessaric:last $last -->"
  } > "$body"
else
  { echo "$marker"; cat "$2"; } > "$body"
fi

if [ -n "$id" ]; then
  out=$(gh api -X PATCH "repos/$repo/issues/comments/$id" -F "body=@$body" 2>&1 >/dev/null) || ok=no
else
  out=$(gh api "repos/$repo/issues/$pr/comments" -F "body=@$body" 2>&1 >/dev/null) || ok=no
fi
if [ "${ok:-yes}" = no ]; then
  case "$out" in
    *403*|*"Resource not accessible"*)
      [ "$mode" = running ] || echo "::notice title=Tessaric::to get the pull request comment, give the job permissions: pull-requests: write" ;;
    *) echo "::warning title=Tessaric::the pull request comment could not be written: ${out%%$'\n'*}" ;;
  esac
fi
rm -f "$body"
