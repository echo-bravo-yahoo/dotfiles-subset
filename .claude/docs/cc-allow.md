# cc-allow Reference

Permission policy engine for Claude Code. Evaluates tool use against TOML rules via PreToolUse hooks.
Exit codes: 0=allow, 1=ask (defer to Claude Code), 2=deny. **Deny always wins.**

## Scope

cc-allow **completely replaces** Claude Code's built-in permission model for: Bash, Read, Write, Edit, WebFetch, Glob, and Grep. When the cc-allow hook is active, every permission decision for these tools flows through cc-allow — Claude Code's own allow/deny lists in `settings.json` are not consulted.

cc-allow does **not** cover: Skills, MCP tools, or Agent spawning. Those still use Claude Code's built-in `permissions.allow`/`permissions.deny` in settings.json.

If a Bash/Read/Write/Edit/Glob/Grep/WebFetch command prompts, cc-allow is always the cause. Never attribute the prompt to Claude Code's built-in system for these tools.

## Config Hierarchy (merged loosely → strictly)

| Level | Path | Purpose |
|---|---|---|
| Global | `~/.config/cc-allow.toml` | User defaults (already extensive) |
| Project | `.config/cc-allow.toml` | Project rules (committed to VCS) |
| Local | `.config/cc-allow.local.toml` | Local overrides (gitignored) |
| Session | `.config/cc-allow/sessions/<id>.toml` | Temporary session rules (auto-cleaned after 30d) |

All configs require `version = "2.0"` at the top.

## Adding Bash Command Permissions

**Allow a command:**
```toml
[bash.allow]
commands = ["mycommand"]
```

**Allow a subcommand** (higher specificity than base command):
```toml
[[bash.allow.npm.run]]
[[bash.allow.docker.compose.up]]
```

**Deny with argument matching:**
```toml
[[bash.deny.git.push]]
message = "Force push blocked"
args.any = ["--force", "flags:f"]
```

**Ask (prompt for confirmation):**
```toml
[[bash.ask.ssh]]
message = "{{.ArgsStr}} - ssh with custom options requires review"
args.any = ["flags:o"]
```

**Scoping allow rules with arg matching:** Allow rules support the same `args` syntax as deny/ask rules. Use this to allow a command only with specific flags:

```toml
# Allow `command -v` (lookup) but not `command <cmd>` (execution)
[[bash.allow.command]]
args.all = ["flags:v"]
```

Without `-v`, the rule doesn't match and the command falls through to `bash.default`.

## Adding File Permissions

Sections: `[read]`, `[write]`, `[edit]`. Each supports `.allow.paths` and `.deny.paths`.

```toml
[read.allow]
paths = ["path:$PROJECT_ROOT/**", "alias:tmp"]

[write.allow]
paths = ["path:$PROJECT_ROOT/**"]

[edit.allow]
paths = ["path:$PROJECT_ROOT/**"]
```

`[glob]` and `[grep]` inherit from `[read]` rules by default (`respect_file_rules = true`).

## URL Permissions

```toml
[webfetch.allow]
paths = ["re:^https://github\\.com/"]

[webfetch.deny]
paths = ["re:^https?://localhost"]
```

URL patterns **must use `re:` prefix** (not `path:`).

## Pattern Prefixes

| Prefix | Use | Example |
|---|---|---|
| `path:` | Glob with variable expansion | `path:$PROJECT_ROOT/**` |
| `re:` | Regex | `re:^--verbose$` |
| `flags:` | Short flag character matching | `flags:rf` matches `-rf`, `-vrf` |
| `flags[delim]:` | Long flag with delimiter | `flags[--]:force` matches `--force` |
| `alias:` | Reference an `[aliases]` entry | `alias:project` |
| (bare string) | Exact literal match | `--force`, `-rf` |

Negation: prefix with `!` (only with explicit prefixes, e.g. `!path:/etc/**`).

## Available Aliases (global config)

| Alias | Expands to |
|---|---|
| `project` | `path:$PROJECT_ROOT/**` |
| `tmp` | `/tmp/**`, `/private/tmp/**` |
| `claude-user-config` | `path:$HOME/.claude/**` |
| `notes` | `path:$HOME/notes/**` |
| `workspace` | `path:$HOME/workspace/**` |
| `sensitive-read` | `.ssh/**`, `*.key`, `*.pem` |
| `sensitive-write` | dotfiles, `/etc/**`, `/usr/**`, system dirs |
| `env-files` | `.env`, `.env.*`, `secrets/**` |

## Variables

- `$PROJECT_ROOT` — directory containing `.claude/` or `.git/`
- `$HOME` — user home directory

`~` is **not** expanded. Always use `$HOME` in paths (e.g., `path:$HOME/.claude/**`, not `path:~/.claude/**`).

**Worktree behavior:** `$PROJECT_ROOT` resolves to the directory containing `.git/`. In a git worktree, this is the **worktree directory** (e.g., `.worktrees/fix-bug/`), not the main repository. Paths in the main repo (like `node_modules` symlink targets) fall outside `alias:project` when working from a worktree. Add an explicit path rule rather than broadening `alias:project`.

## Specificity Rules

When multiple rules match, **most specific wins**. Scoring:
- Named command: +100
- Each subcommand level: +50 (e.g. `git.push` = 150)
- Each `args.position` entry: +20
- Each `args.any`/`args.all` item: +5

On tie: deny > ask > allow.

## Argument Matching

```toml
args.any = [...]       # at least one must match (OR)
args.all = [...]       # all must match (AND)
args.not = { ... }     # negate the match
args.position = { "0" = "status" }  # absolute position matching
```

## Validating a Config Change

Run these steps, in order, on every edit to any cc-allow config file. Stop at the first step that doesn't clear before fixing and restarting the loop — do not stack edits.

1. **Run `cc-allow --fmt`** to validate TOML syntax and print all rules sorted by specificity. Exit code 3 with `ERROR` lines means the config is broken — stop and fix before moving on.
   ```bash
   cc-allow --fmt                         # all loaded configs
   cc-allow --fmt --config ./rules.toml   # a single file
   ```

2. **Run `cc-allow --debug` on the exact command that was prompting.** The debug flag is read-only, accepts the command on **stdin only** (passing it as an argument silently returns "no command"), and prints the full evaluation trace: parsed name/args, matched rules with specificity scores, and the final decision. Only `decision=allow` counts as fixed. Four things must be right about how you run it:
   - **Use the user's pasted command verbatim.** When the user pastes a permission prompt error, the command block in that prompt is the exact string Claude Code sent to cc-allow — copy it byte-for-byte into stdin. Do not retype, truncate, or summarize; a different string exercises different rules.
   - **Pipe multi-line commands with `cat <<'CMD'`, not `echo`.** `echo` collapses embedded newlines and escapes, producing a shorter string than the real command. For heredocs and multi-line bodies:
     ```bash
     cat <<'CMD' | cc-allow --debug
     cat > /path/to/file << 'CTXEOF'
     body line 1
     body line 2
     CTXEOF
     CMD
     ```
   - **Match the worktree the prompt fired in.** `$PROJECT_ROOT` resolves to the directory containing `.git/`, which in a worktree is the worktree dir, not the main repo. `cd` into the worktree before piping, or export `PROJECT_ROOT=<worktree-path>`. Running the test from the main repo evaluates against a different `$PROJECT_ROOT` and will silently disagree with what the real command sees. See "Variables → Worktree behavior" above.
   - **Test on behalf of the right agent / session.** Agents and subagents get session-specific configs at `.config/cc-allow/sessions/<session-id>.toml` layered on top of the global/project/local chain. To evaluate what an agent sees, include its session file explicitly:
     ```bash
     echo '<command>' | cc-allow --debug \
       --config .config/cc-allow/sessions/<agent-session-id>.toml
     ```
     Without `--config`, the test uses your own session's rules, not the agent's — a rule added to the agent's session file won't appear to work when tested from the parent session, and vice versa.

3. **Check every evaluation the command triggers, not just the first.** Commands with redirects (`>`, `>>`), symlinks (`ln -s`), or heredocs fire a secondary write check on the target path in addition to the bash check. All passes must return `allow`:
   ```bash
   echo '/path/to/target/file' | cc-allow -write --debug
   ```
   See "Cross-Tool Evaluation" below for the full list of secondary evaluations and `source=` markers.

4. **Only move on when every decision is `allow`.** Further edits, declaring the issue fixed, or unblocking the user's task — none of these happen before steps 2–3 return `allow` in the correct environment. Re-verify after each edit. If the same prompt recurs, the edit didn't match — see "Debugging a Permission Prompt" below for deeper diagnosis (JSONL replay to find the exact prompting command, compound-command decomposition, and variable-resolution theories).

## Common Tasks

**Permission prompt keeps firing for a safe command:**
Add to `[bash.allow] commands` in the appropriate config level.

**Project script prompts despite being in allow list:**
cc-allow resolves commands to absolute paths before matching. A relative entry like `.claude/scripts/foo.sh` won't match when cc-allow sees `/full/path/.claude/scripts/foo.sh`. Use a `path:` pattern instead: `"path:$PROJECT_ROOT/.claude/scripts/**"`. This is especially common for project-local scripts invoked by agents or skills.

**Need project-specific access:**
Create `.config/cc-allow.toml` in the project root.

**Temporary session need:**
Create `.config/cc-allow/sessions/<session-id>.toml`.

**A rule exists for a concept but prompts from an unexpected invocation or tool:**
Walk the Duplicate-Entry Patterns section below to find the cooperating entry the concept is missing.

## Duplicate-Entry Patterns

Several cc-allow mechanics force a single concept (one script, one command, one protected path) to need multiple cooperating entries. The patterns below are phrased as authoring rules: when adding or editing a rule that fits the trigger, the corresponding cooperating entry must also exist.

See Cross-Tool Evaluation below for the underlying mechanics these rules compensate for.

### 1. Tilde non-expansion

cc-allow sees the literal `~` — no shell expansion happens before matching. `path:$HOME/...` globs match bare-name (PATH-resolved) and absolute-path forms, but not the tilde form.

**When adding or editing a rule for a command or script that may be invoked with a `~/...` path, ensure a tilde-literal string appears in `bash.allow.commands` alongside the path-glob or alias entry.**

### 2. Short-flag / long-flag variants

cc-allow matches arg strings literally. `-i` and `--in-place` are different strings; rules on one do not catch the other. `flags:<char>` handles short-flag grouping (`flags:f` matches `-f`, `-rf`, `-vrf`).

**When adding or editing a rule that targets a flag, ensure the short form (`flags:<char>`) and every long-form string the flag accepts are both enumerated.**

### 3. Deny-dangerous + allow-safe-wrapper

When a command is unsafe raw but a wrapper script constrains it, cc-allow must simultaneously deny the raw form and allow the wrapper.

**When adding or editing a deny rule whose message points to a safer wrapper, ensure the wrapper is (a) present on disk, (b) in `bash.allow.commands` covering every invocation form the user documents (see Pattern 1 for tilde), (c) named explicitly in the deny message.**

### 4. Read/Write/Edit parity on sensitive paths

File tools split into three independent sections: `[read]`, `[write]`, `[edit]`. A path denied in one but not the others leaves a hole the agent can route through via the other tool.

**When adding or editing a rule for a path in any of `read`, `write`, `edit`, ensure the other two sections have a compatible rule. Sensitive paths (credentials, SSH keys, env files) should deny in all three; sanctioned work areas should allow in all three. Asymmetry must be deliberate and commented.**

### 5. Redirect + write parity

Output redirection (`cmd > /path`) triggers a check in `[bash.redirects]` in addition to the bash command check. With `respect_file_rules = true`, `[write]` rules also apply. Both layers evaluate.

**When adding or editing a rule that restricts writes to a path, ensure it is covered by both `[bash.redirects]` and `[write]` in the same direction. A path denied in `write` but allowed as a redirect target is routed-around.**

### 6. Bash-command / file-tool parity

File-tool denies (`edit.deny`, `write.deny`) stop the `Edit` and `Write` tools. They do not stop a shell command from achieving the same effect (`tee`, `sed -i`, `cp -f`, `rm`, `chmod`, `>`, `>>`) unless the secondary redirect/write checks fire.

**When adding or editing a file-tool deny for a path, ensure at least one of the following holds for each mutating bash command: the command itself is denied (e.g. `sed -i`), or the path is in `write.deny` / `bash.redirects.deny` so the secondary check catches writes routed through shell.**

### 7. File-viewer secondary read check

`cat`, `head`, `tail`, `less` are in `bash.allow.commands`, but each file argument triggers a read check against `[read.allow]`. Bash-side allow is necessary but not sufficient.

**When adding or editing a directory where an agent is expected to read files via bash commands, ensure the directory is in `[read.allow].paths`.** On macOS, `$TMPDIR` resolves under `/private/var/folders/**` — `alias:tmp` must include that glob (or an explicit `read.allow` entry must) for `mktemp`-style reads to allow.

## Cross-Tool Evaluation

A single tool use can trigger **multiple evaluation passes**. If the primary rule allows a command but it still prompts, a secondary evaluation in a different section is the cause. See Duplicate-Entry Patterns above for the authoring rules these mechanics impose.

Known secondary evaluations:
- `ln -s <target> <link>` → write check on the symlink target path
- Commands with redirects (`>`, `>>`) → write check on the redirect target (governed by `[bash.redirects]` rules)
- File-viewer commands (`cat`, `tail`, `head`, `less`, `more`, etc.) → read check on each file argument. The bash command may be in `bash.allow.commands`, but the file path must also satisfy `[read.allow]`.

The `source=` field in debug output identifies which section triggered the prompt:
- `source="...bash.allow.commands"` → bash rule
- `source="...write default"` or `source="...write.allow.paths"` → file write rule

Diagnose by testing each evaluation independently:
```bash
echo 'ln -s /target /link' | cc-allow --debug        # bash check
echo '/target' | cc-allow -write --debug              # write check
```

Tool-type flags for secondary checks: `-write`, `-read`, `-edit`, `-glob`, `-grep`, `-fetch`.

## Debugging a Permission Prompt

When investigating why a command prompted, don't assume it was the most recent command — the user may have queued their complaint while other commands were running. The conversation log does not distinguish accepted prompts from auto-allowed commands (both appear as successful tool results with `is_error: false`).

**Find the prompting command** by extracting Bash commands from the JSONL in reverse and replaying each through `cc-allow --debug` until one returns non-allow:
```bash
# NUL-delimited to handle multi-line commands (heredocs)
cmds=()
while IFS= read -r -d '' cmd; do cmds+=("$cmd"); done < <(
  jq -rj 'select(.type == "assistant") | .message.content[]?
    | select(.type == "tool_use" and .name == "Bash")
    | .input.command + "\u0000"' ~/.claude/projects/*/SESSION_ID.jsonl
)
for (( i=${#cmds[@]}-1; i>=0; i-- )); do
  result=$(printf '%s' "${cmds[$i]}" | cc-allow --debug 2>&1 | tail -1)
  case "$result" in
    *"Ask:"*|*"Deny:"*) echo "$result"; echo "Command: ${cmds[$i]}"; break ;;
  esac
done
```

**Compound commands:** When a chained command (`a && b && c`) prompts, test each part individually:
```bash
echo 'rm -rf node_modules' | cc-allow --debug
echo 'ln -s /path/to/target link_name' | cc-allow --debug
echo 'ls node_modules/ | head -5' | cc-allow --debug
```

**Before adding a rule, understand why existing rules don't match.** When a path should be covered by an existing rule (like `alias:project`) but isn't:

1. **Form a theory** about which variable resolved incorrectly
2. **Test the theory** by setting the variable explicitly:
```bash
# Theory: PROJECT_ROOT is resolving to a worktree, not the main repo
echo '/path/that/prompted' | PROJECT_ROOT=/expected/value cc-allow -write --debug
echo '/path/that/prompted' | PROJECT_ROOT=$(pwd) cc-allow -write --debug
```

If the rule matches with one value but not the other, the variable resolution is the root cause. Fix the narrowest thing that's actually wrong — don't add a broader rule to paper over a variable mismatch.

## Full Reference

This doc covers common usage. For advanced features (boolean argument expressions, position matching, pipe context, `ref:` cross-references, per-rule file config, heredoc rules, Safe Browsing integration), find `docs/config.md` in the cc-allow repo (one directory up from the binary: `$(dirname "$(realpath "$(command -v cc-allow)")")/..`).
