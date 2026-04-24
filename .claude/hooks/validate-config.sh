#!/bin/bash
set -euo pipefail

HOOK_JSON=$(cat)
FILE_PATH=$(printf '%s' "$HOOK_JSON" | jq -r '.tool_input.file_path // empty')
[ -z "$FILE_PATH" ] && exit 0

EXT="${FILE_PATH##*.}"
EXT=$(printf '%s' "$EXT" | tr '[:upper:]' '[:lower:]')

case "$EXT" in
  json|toml|jsonl) ;;
  *) exit 0 ;;
esac

TOOL_NAME=$(printf '%s' "$HOOK_JSON" | jq -r '.tool_name // empty')

# Get content to validate
if [ "$TOOL_NAME" = "Write" ]; then
  CONTENT=$(printf '%s' "$HOOK_JSON" | jq -r '.tool_input.content // empty')
elif [ "$TOOL_NAME" = "Edit" ]; then
  [ -f "$FILE_PATH" ] || exit 0
  CONTENT=$(cat "$FILE_PATH")
else
  exit 0
fi

[ -z "$CONTENT" ] && exit 0

# Validate
ERRORS=""
case "$EXT" in
  json)
    ERRORS=$(printf '%s' "$CONTENT" | jq . 2>&1 >/dev/null) || true
    ;;
  toml)
    if command -v taplo >/dev/null 2>&1; then
      ERRORS=$(printf '%s' "$CONTENT" | taplo check - 2>&1) || true
    fi
    ;;
  jsonl)
    LINE_NUM=0
    while IFS= read -r line; do
      LINE_NUM=$((LINE_NUM + 1))
      [ -z "$line" ] && continue
      LINE_ERR=$(printf '%s' "$line" | jq . 2>&1 >/dev/null) || true
      if [ -n "$LINE_ERR" ]; then
        ERRORS="Line $LINE_NUM: $LINE_ERR"
        break
      fi
    done <<< "$CONTENT"
    ;;
esac

[ -z "$ERRORS" ] && exit 0

# Validation failed
if [ "$TOOL_NAME" = "Write" ]; then
  # PreToolUse: deny the write
  jq -n --arg r "Invalid $EXT: $ERRORS" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
elif [ "$TOOL_NAME" = "Edit" ]; then
  # PostToolUse: alert with system message
  jq -n --arg msg "The file $FILE_PATH is now invalid $EXT. Parse error: $ERRORS. Fix this file immediately." '{
    systemMessage: $msg
  }'
  exit 2
fi
