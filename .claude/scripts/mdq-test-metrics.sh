#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: mdq-test-metrics.sh <baseline-session-id> <mdq-session-id>"
  echo "Compares token metrics between two sessions."
  exit 1
fi

find_session() {
  find ~/.claude/projects -name "$1.jsonl" -print -quit 2>/dev/null
}

extract_metrics() {
  local file
  file=$(find_session "$1")
  if [[ -z "$file" ]]; then
    echo "Session not found: $1" >&2
    exit 1
  fi
  jq -s '{
    turns: ([.[] | select(.type == "assistant")] | length),
    peak: ([.[] | select(.type == "assistant") | .message.usage |
      (.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens)] | max),
    cumul: ([.[] | select(.type == "assistant") | .message.usage |
      (.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens + .output_tokens)] | add)
  }' "$file"
}

baseline=$(extract_metrics "$1")
mdq_run=$(extract_metrics "$2")

jq -n --argjson b "$baseline" --argjson m "$mdq_run" '
  def pct: if . == 0 then "n/a" else "\(. * 100 | round)%" end;
  def delta($a; $b): ($b - $a) | tostring + " (" + (if $a == 0 then "n/a" else (($b - $a) / $a) | pct end) + ")";
  "| Metric         | Baseline   | mdq        | Delta              |",
  "|----------------|------------|------------|--------------------|",
  "| Turns          | \($b.turns | tostring | .[0:10] | . + " " * (10 - length)) | \($m.turns | tostring | .[0:10] | . + " " * (10 - length)) | \(delta($b.turns; $m.turns) | .[0:18] | . + " " * (18 - length)) |",
  "| Peak context   | \($b.peak | tostring | .[0:10] | . + " " * (10 - length)) | \($m.peak | tostring | .[0:10] | . + " " * (10 - length)) | \(delta($b.peak; $m.peak) | .[0:18] | . + " " * (18 - length)) |",
  "| Cumul tokens   | \($b.cumul | tostring | .[0:10] | . + " " * (10 - length)) | \($m.cumul | tostring | .[0:10] | . + " " * (10 - length)) | \(delta($b.cumul; $m.cumul) | .[0:18] | . + " " * (18 - length)) |"
' -r
