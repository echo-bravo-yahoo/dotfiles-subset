#!/usr/bin/env bash
set -euo pipefail

CLAUDE_MD=~/.claude/CLAUDE.md
METRICS_SCRIPT=~/.claude/scripts/mdq-test-metrics.sh
OLAPUI_DIR=~/workspace/olapui
PROMPT='Read node_modules/@vlognow/mac-ui/docs/developer-guide.md and tell me: How do I implement custom event dispatching in a MacElement? Include code examples.'

SECTION_HEADING='## Markdown Traversal'
SECTION_BODY='**Before using Read on any `.md` file, run `wc -l` first.** If it exceeds 500 lines, do NOT use Read — instead: (1) Grep for `^#{1,6} ` to scan headings, then (2) `mdq` in Bash to extract only the relevant section. See `~/.claude/docs/markdown-traversal.md` for selector syntax and examples.'

remove_section() {
  awk '
    /^## Markdown Traversal$/ { skip=1; next }
    skip && /^## / { skip=0 }
    skip { next }
    { print }
  ' "$CLAUDE_MD" > "${CLAUDE_MD}.tmp"
  mv "${CLAUDE_MD}.tmp" "$CLAUDE_MD"
}

restore_section() {
  awk -v heading="$SECTION_HEADING" -v body="$SECTION_BODY" '
    /^## Testing Changes$/ {
      print heading
      print ""
      print body
      print ""
    }
    { print }
  ' "$CLAUDE_MD" > "${CLAUDE_MD}.tmp"
  mv "${CLAUDE_MD}.tmp" "$CLAUDE_MD"
}

run_test() {
  local label=$1
  echo "=== $label ===" >&2
  local result
  result=$(cd "$OLAPUI_DIR" && echo "$PROMPT" | claude -p --output-format json 2>/dev/null)
  local session
  session=$(echo "$result" | jq -r '.session_id')
  echo "Session: $session" >&2
  echo "$result" | jq -r '.result' | head -20 >&2
  echo "..." >&2
  echo "" >&2
  # Return only the session ID on stdout
  echo "$session"
}

# --- Pre-flight ---
if ! grep -q "^## Markdown Traversal$" "$CLAUDE_MD"; then
  echo "Error: Markdown Traversal section not in CLAUDE.md — nothing to test" >&2
  exit 1
fi

# --- Run 1: with mdq doc ---
mdq_session=$(run_test "Run 1: WITH mdq doc")

# --- Remove section ---
echo "=== Removing Markdown Traversal section ==="
remove_section
if grep -q "^## Markdown Traversal$" "$CLAUDE_MD"; then
  echo "Error: removal failed" >&2
  exit 1
fi
echo "Removed."
echo ""

# --- Run 2: baseline ---
baseline_session=$(run_test "Run 2: WITHOUT mdq doc (baseline)")

# --- Restore section ---
echo "=== Restoring Markdown Traversal section ==="
restore_section
if ! grep -q "^## Markdown Traversal$" "$CLAUDE_MD"; then
  echo "Error: restore failed" >&2
  exit 1
fi
echo "Restored."
echo ""

# --- Compare ---
echo "=== Metrics comparison (baseline vs mdq) ==="
bash "$METRICS_SCRIPT" "$baseline_session" "$mdq_session"
