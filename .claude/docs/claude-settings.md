# Claude Code Settings & Hooks

## Settings file locations

| File | Scope | Purpose |
|---|---|---|
| `~/.claude/settings.json` | Global | User-wide defaults |
| `.claude/settings.json` | Project | Project-specific (committed to VCS) |
| `.claude/settings.local.json` | Local | Local overrides (gitignored) |

## Settings structure

```json
{
  "permissions": {
    "allow": ["WebSearch", "mcp__toolname"],
    "deny": []
  },
  "hooks": {
    "PreToolUse": [...],
    "PostToolUse": [...],
    "SessionStart": [...],
    "SessionEnd": [...],
    "Notification": [...],
    "UserPromptSubmit": [...],
    "Stop": [...]
  },
  "model": "opus",
  "env": { "KEY": "value" }
}
```

## Permission boundary: cc-allow vs native

Two systems manage permissions. Do not mix them.

**cc-allow** (via PreToolUse hook) manages: `Bash`, `Read`, `Write`, `Edit`, `WebFetch`, `Glob`, `Grep`. All rules for these tools go in `~/.config/cc-allow.toml` (or project/local/session TOML overrides). Never add `Bash(...)` entries to `settings.json permissions.allow` — they bypass cc-allow's deny/ask rules.

**Native `permissions.allow`** manages everything cc-allow cannot hook into:
- `WebSearch`
- MCP tools (`mcp__*`)

**Guiding principle**: read-only and mutate-existing tools are auto-allowed. Tools that create new visible/shared resources (new Figma files, new Slack messages, new service accounts) should prompt.

Tools that should prompt (not in `permissions.allow`):
- Slack: `slack_send_message`, `slack_schedule_message`, `slack_create_canvas`
- Figma: `create_new_file`, `generate_figma_design`, `generate_diagram`, `create_design_system_rules`
- Machinify: `mfy_chart_create`, `mfy_project_service_account_add`, `mfy_project_service_account_revoke`, `mfy_project_service_account_token`

## Hook structure

Each hook event contains an array of hook groups. Each group has an optional `matcher` (regex against tool name) and a `hooks` array:

```json
{
  "matcher": "Bash|Read|Write|Edit",
  "hooks": [
    {
      "type": "command",
      "command": "some-command --flag",
      "async": false
    }
  ]
}
```

- `matcher` — regex matched against tool name. Omit to match all tools.
- `async: true` — hook runs in background, doesn't block tool execution
- `async: false` (default) — hook blocks and can approve/deny the action

## Hook safety: always syntax-check before registering

A syntax error in a PreToolUse hook that matches broad tools (`Bash|Read|Write|Edit|WebFetch|Glob|Grep`) blocks **every** tool call, making it impossible to self-fix from within Claude Code. The user must intervene manually via `! sed` or an editor.

Before registering or modifying a hook script:
1. Write the script file
2. Run `bash -n <script>` to verify syntax
3. Only then add/update the hook entry in `settings.json`

When editing an existing hook, verify syntax after every change — a single `; do` vs `; then` typo can lock out all tools.

## Neovim parity principle

Claude Code and neovim must use the same linting and formatting tools. Neovim's config is the source of truth for linting tool choices:

- **nvim-lint config**: `~/.config/nvim/lint.lua` — defines linters per filetype
- **LSP config**: `~/.config/nvim/lsp.lua` — defines language servers (some provide linting)
- **Formatter config**: `~/.config/nvim/text-editing.vim` — prettier setup

When adding or changing a linting/formatting tool in Claude Code docs, verify it matches what neovim uses. When updating neovim's linting config, update the corresponding Claude Code docs file too.

Per-language tool details are in separate docs:
- `~/.claude/docs/node.md` — eslint, prettier, biome, tsc
- `~/.claude/docs/python.md` — ruff
- `~/.claude/docs/rust.md` — cargo clippy, cargo fmt
- `~/.claude/docs/lua.md` — stylua
- `~/.claude/docs/shell.md` — shellcheck
- `~/.claude/docs/github-actions.md` — actionlint
