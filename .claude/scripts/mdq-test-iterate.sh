#!/usr/bin/env bash
set -euo pipefail

# Automated test: did Claude avoid Read on the full file as its first action?
# Pass = first tool call is Grep or Bash(mdq), not Read without offset
# Fail = first tool call is Read with no offset on a large file

OLAPUI_DIR=~/workspace/olapui
PROMPT='Read node_modules/@vlognow/mac-ui/docs/developer-guide.md and tell me: How do I implement custom event dispatching in a MacElement? Include code examples.'

run_and_check() {
  local label=$1
  echo "=== Testing: $label ==="

  local result
  result=$(cd "$OLAPUI_DIR" && echo "$PROMPT" | claude -p --output-format json 2>/dev/null)
  local session
  session=$(echo "$result" | jq -r '.session_id')
  local file
  file=$(find ~/.claude/projects -name "${session}.jsonl" -print -quit 2>/dev/null)

  if [[ -z "$file" ]]; then
    echo "  FAIL: session file not found ($session)"
    return 1
  fi

  # Extract all tool calls in order
  local tools
  tools=$(jq -c 'select(.type == "assistant") | .message.content[] | select(.type == "tool_use") | {name, file: .input.file_path, offset: .input.offset, command: .input.command, pattern: .input.pattern}' "$file")

  echo "  Session: $session"
  echo "  Tool calls:"
  echo "$tools" | while read -r line; do
    echo "    $line"
  done

  # Check: was the first tool call a full-file Read (no offset)?
  local first_tool
  first_tool=$(echo "$tools" | head -1)
  local first_name
  first_name=$(echo "$first_tool" | jq -r '.name')
  local first_offset
  first_offset=$(echo "$first_tool" | jq -r '.offset')

  if [[ "$first_name" == "Read" && "$first_offset" == "null" ]]; then
    echo "  RESULT: FAIL — first action was Read on full file"
    return 1
  else
    echo "  RESULT: PASS — first action was $first_name (not a full-file Read)"

    # Bonus: check if Read without offset was used at all
    local full_reads
    full_reads=$(echo "$tools" | jq -c 'select(.name == "Read" and .offset == null)' | wc -l | tr -d ' ')
    if [[ "$full_reads" -gt 0 ]]; then
      echo "  NOTE: Read without offset was used later ($full_reads times)"
    fi
    return 0
  fi
}

run_and_check "$@"
