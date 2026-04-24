#!/bin/bash
# PreToolUse hook: deny permission-management skills (update-config,
# fewer-permission-prompts) with a message redirecting the agent to
# cc-allow for permission management.
# Matcher: "Skill" — receives every Skill tool call; no-ops on others.

input=$(cat)
tool=$(printf '%s' "$input" | jq -r '.tool_name // ""')
skill=$(printf '%s' "$input" | jq -r '.tool_input.skill // ""')

if [ "$tool" = "Skill" ] && { [ "$skill" = "update-config" ] || [ "$skill" = "fewer-permission-prompts" ]; }; then
  reason="The ${skill} skill is disabled in this environment. Permissions are managed via cc-allow (TOML-based policy engine), not Claude Code's built-in permissions.allow/deny lists. Read ~/.claude/docs/cc-allow.md for how to add or modify permission rules (global config: ~/.config/cc-allow.toml; project config: .config/cc-allow.toml; session overrides: .config/cc-allow/sessions/<id>.toml). Note: cc-allow covers Bash, Read, Write, Edit, WebFetch, Glob, and Grep only — Skills, MCP tools, and Agent spawning still use settings.json permissions.allow/deny. For non-permission settings.json changes (hooks, env vars, model, statusLine, etc.), use the Edit or Write tool directly on ~/.claude/settings.json."
  jq -n --arg reason "$reason" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
fi
exit 0
