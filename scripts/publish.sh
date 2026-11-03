#!/usr/bin/env bash
# Publishes a finished run: at most 10 line notes for what can fail, the run's summary page (the
# full report under the banner) and the pull request comment (one line, with what can fail
# folded under it). Reads the files verify left in $REPORT_DIR.
set -euo pipefail

dir=$REPORT_DIR
code=$CODE
prefix=""
[ "$WORKSPACE" = . ] || prefix="${WORKSPACE%/}/"
run_url="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
blob="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/blob/$TESSARIC_SHA"

count() { jq "[.obligations.counts[]?.counts | $1] | add // 0" "$dir/tessaric-report.json" 2>/dev/null || echo 0; }
proved=$(count '(.proved // 0) + (.proved_to_bound // 0)')
can_fail=$(count '.can_fail // 0')
open=$(count '.open // 0')

case "$code" in
  0) status="ok" ;;
  1) if [ "$can_fail" -gt 0 ]; then status="$can_fail can fail"; else status="checks failed"; fi ;;
  3) status="nothing proved yet" ;;
  130) status="interrupted" ;;
  *) status="could not determine" ;;
esac
counts=""
case "$code" in 0|1|3) counts=" · $proved proved · $open open" ;; esac

# What can fail, as (title, sentence without its trailing place, file, line), at most 10.
fails=$(mktemp)
if [ -s "$dir/attention.jsonl" ]; then
  jq -c 'select(.group? == "can_fail")
    | {title, kind, file, line, s: (.sentence | sub(" \\([^()]*:[0-9]+(:[0-9]+)?\\)$"; ""))}' \
    "$dir/attention.jsonl" | head -n 10 > "$fails" || true
fi
shown=$(wc -l < "$fails")

if [ "$ANNOTATIONS" = true ]; then
  # workflow commands escape % and line breaks in the message, and : and , in a property
  jq -r --arg p "$prefix" '
    def data: gsub("%"; "%25") | gsub("\r"; "%0D") | gsub("\n"; "%0A");
    def prop: data | gsub(":"; "%3A") | gsub(","; "%2C");
    (if .file then "file=\("\($p)\(.file)" | prop)" + (if .line then ",line=\(.line)" else "" end) + "," else "" end) as $at
    | "::error \($at)title=\("Tessaric: can fail, \(.kind)" | prop)::\("\(.title) \(.s)" | data)"' "$fails"
fi

if [ "$SUMMARY" = true ]; then
  {
    printf '%s&nbsp; **%s**%s\n\n' "$TESSARIC_BANNER_LARGE" "$status" "$counts"
    if [ -s "$dir/tessaric-report.md" ]; then cat "$dir/tessaric-report.md"; else echo "Tessaric wrote no report (verify exited $code)."; fi
  } >> "$GITHUB_STEP_SUMMARY"
fi

if [ "$COMMENT" = true ]; then
  body=$(mktemp)
  {
    printf '%s&nbsp; **%s**%s · [report](%s)\n' "$TESSARIC_BANNER" "$status" "$counts" "$run_url"
    if [ "$shown" -gt 0 ]; then
      printf '<details><summary>What can fail</summary>\n\n'
      jq -r --arg p "$prefix" --arg b "$blob" '
        "- `\(.title)` \(.s)" + (if .file then " · [\(.file | split("/") | last)\(if .line then ":\(.line)" else "" end)](\($b)/\($p)\(.file)\(if .line then "#L\(.line)" else "" end))" else "" end)' "$fails"
      [ "$can_fail" -le "$shown" ] || printf -- '- and %s more in the [report](%s)\n' "$((can_fail - shown))" "$run_url"
      printf '\n</details>\n'
    fi
    echo "<!-- tessaric:last $status -->"
  } > "$body"
  bash "$GITHUB_ACTION_PATH/scripts/comment.sh" final "$body"
  rm -f "$body"
fi
rm -f "$fails"
