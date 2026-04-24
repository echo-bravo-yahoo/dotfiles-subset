# Communication Style

## Brevity
- Prefer short, direct responses over verbose explanations
- Minimize adjectives, especially positive qualifiers ("great", "excellent", "perfect")
- State facts and actions plainly without preamble or summary padding

## Generalize Before Illustrating

When writing docs, comments, help text, or instructional prose that contains a general pattern: express the pattern first, then illustrate with examples. Don't enumerate specifics as a substitute for the pattern.

If the general pattern isn't obvious, form a hypothesis and validate it with tools — check both cases that should match and cases that shouldn't before committing to the generalization.

## Pronouns
- Avoid first-person ("I will...", "I found...") and second-person ("You can...", "You should...")
- Prefer passive voice, imperative mood, or noun-focused phrasing when natural
- Examples:
  - Instead of "I found the file at..." → "The file is at..."
  - Instead of "You can run this command" → "Run:" or "This command..."
  - Instead of "I'll update the config" → "Updating the config..."

## Links in Output
- When output includes links (URLs, PR references, issue references, etc.), render them as markdown links: `[display text](URL)`
- Use concise display text — e.g., `repo#123` for GitHub PRs/issues, a short title for other URLs
- This makes links clickable in the terminal while keeping output scannable

## Clipboard Convenience
- When a conversation concludes with a single link, command, or short text snippet the user clearly intends to use, copy it to the system clipboard using `pbcopy`
- Briefly note when something has been copied (e.g., "(copied)")

## Units & Measurements

When reporting prices, quantities, or other values with units (currency, weight, distance, etc.), see `~/.claude/docs/unit-preferences.md` for conventions — especially for currency conversion.

## Task Recaps
- At the conclusion of a task or discussion, or when asked to recap, list any commands that:
  - Required permission prompts before running
  - Failed on the first attempt but succeeded on retry
- Present these as a simple list so the user can adjust permissions or system prompts to streamline future sessions

## Shell State

When deleting a directory that is the current working directory, `cd` out first to avoid breaking shell state. If the shell breaks (all commands return exit code 1 with no output), restart the conversation.

## tmux

After editing `~/.tmux.conf`, reload it with:
```bash
tmux source-file ~/.tmux.conf
```
This applies changes to the current session immediately.

When adding tmux keybindings, always check if the key has a default binding. Prompt before overwriting standard tmux bindings.

## Dotfile Syncing

Multi-session / multi-host model — assume concurrent sessions and hosts edit this repo. Full architecture in `~/.claude/docs/dotfiles.md`; canonical rules here:

- **Gather is automatic.** A watcher daemon (launchd on macOS, systemd user service on Linux/WSL) runs `wildflower gather` on every fs change to tracked paths. Never invoke `wildflower` directly — cc-allow denies bare `wildflower gather|sow|till`. The watcher logs to `~/.aeby/logs/dotfiles-watcher.log`.
- **Commit selectively.** After editing a tracked home file, stage only the specific `meadows/~~/...` path that mirrors what you just edited. Never `git add -A` in this repo — cc-allow denies it. Never commit paths you didn't edit.
- **Commit message**: subject `<subsystem>: <description>`, optional body, then a blank line, then the bare Claude Code session ID (`$CLAUDE_SESSION_ID`) as the last body line. No label, no "Session:" prefix, no "claude" word or LLM attribution — just the ID.
- **Pulling is scripted.** Never `git pull` in this repo directly — cc-allow denies it. Always run `~/.aeby/scripts/dotfiles-update.sh`, which performs `gather → stash → pull --rebase → pop → sow` and writes a freshness marker at `.last-update`.
- **Push whenever the update script has run.** The pre-push hook refuses push if the marker doesn't match current `origin/main`. Override only via `--no-verify` if you know what you're doing.
- **Failure recovery.** If the update script or pre-push hook exits 2, its stderr contains remediation. Read it. Don't blindly retry — fix the stated cause first.

Tracked-path list: `~/workspace/dotfiles/meadows.mjs`. Emergency-checkpoint skill: `/gather` (fallback only; do not use for routine sync).

## Bash Portability

Both macOS and Linux are in use. Write portable bash scripts:

- Use `grep -o` + `sed` instead of `grep -oP` (Perl regex is GNU grep only)
- Use `sed` instead of `sed -i ''` or `sed -i` (in-place flags differ)
- Use `date -u` for UTC; avoid GNU-specific `date -d`
- Use `command -v` instead of `which`
- Avoid bash 4+ features (associative arrays, `${var,,}`) on macOS default bash 3.2

## CLI Design

When building or modifying a CLI tool, read https://clig.dev/ for interface design guidance (flags, help text, output, error handling, etc.).

## Tool Over Bash

Never use Bash to replicate what a dedicated tool does:

- **Line ranges**: `Read` with `offset`/`limit`, not `sed -n '10,20p'`
- **File contents**: `Read`, not `cat`, `head`, `tail` (exception: markdown files over 500 lines — see Markdown Traversal below)
- **Search by content**: `Grep`, not `grep` or `rg`
- **Search by name**: `Glob`, not `find` or `ls`
- **Edit files**: `Edit`, not `sed` or `awk`
- **Create files**: `Write`, not `echo >` or heredoc redirect

Reserve Bash for commands that have no tool equivalent (git, npm, build tools, etc.).

- **JSON parsing**: `jq` in Bash, never `python`/`python3`. `jq` is installed and pre-allowed; `python` always prompts for permission. This applies to any JSON task `jq` can handle: extraction, transformation, filtering, formatting.

## Grep Regex and Permissions

When using `grep` in Bash with a regex pattern starting with `/` (e.g., `grep -v "//\s*"`), cc-allow may trigger a false file-read permission prompt — it misidentifies the regex as a file path. To avoid this:

- Escape the leading slash: `grep "\/pattern"` instead of `grep "/pattern"`
- Use a bracket expression: `grep "[/]pattern"` instead of `grep "/pattern"`

Both produce identical grep behavior but prevent the false permission check.

## Markdown Traversal

**Before using Read on any `.md` file, run `wc -l` first.** If it exceeds 500 lines, do NOT use Read — instead: (1) Grep for `^#{1,6} ` to scan headings, then (2) `mdq` in Bash to extract only the relevant section. See `~/.claude/docs/markdown-traversal.md` for selector syntax and examples.

## Testing Changes

After making code changes, run applicable test suites in this order:

1. **Formatting** (if repo has formatter config): `prettier`, `biome format`, etc.
2. **Linting** (if repo has linter config): `eslint`, `biome lint`, `tsc --noEmit`, etc.
3. **Unit tests**: Scope to files/modules affected by the change
4. **Integration tests**: Scope to features touched by the change
5. **E2E tests**: Scope to workflows affected by the change

**Scoping rules:**
- Run only the subset of a test suite that covers the changes made
- Skip a test suite entirely if no tests cover the changed code
- When unsure what tests exist, explore the test directory structure first

## Pre-existing Failures

When running tests, linters, type checks, or builds during a task, failures unrelated to the current changes may appear. Handle these as follows:

- Do not get derailed — continue completing the current task
- Do not silently ignore them — track each pre-existing failure encountered
- At task completion, include a "Pre-existing failures" section listing what was observed (tool, file, error summary)
- If uncertain whether a failure is pre-existing or caused by current changes, note it with that uncertainty

## LSP Diagnostic Staleness

LSP diagnostics delivered passively (not from an explicit lint/typecheck command) may reflect a previous file state due to async delivery lag. After editing a file:

- Do not blindly act on LSP diagnostics for files just edited — they may be stale
- If diagnostics appear for a recently-edited file, re-read the flagged lines to verify the errors still exist before attempting fixes
- Prefer running explicit lint/typecheck commands (e.g., `tsc --noEmit`, `eslint`) over relying on passive diagnostics when accuracy matters
- If the same diagnostic reappears after an explicit check, it's real — fix it

## Build After Changes

After completing work and running tests, build the project if the project CLAUDE.md documents a build command.

- Use **only** the build command from the project CLAUDE.md — do not guess or search for build methods
- If no build instructions exist in the project CLAUDE.md, skip this step
- Also rebuild after moving changes onto a branch (merge, cherry-pick, rebase) if that branch has a build step
- Order: make changes → run tests → build

## Opening Files

When asked to open a file, URL, or directory, see `~/.claude/docs/open-files.md` for the correct handler (nvim vs OS default) and invocation method per environment. Never run interactive editors as foreground Bash commands.

## Opening Terminal Windows or Tabs

When asked to open a new terminal window or tab to a directory (with or without a starting command), use `~/.aeby/scripts/ghostty-window.sh` or `~/.aeby/scripts/ghostty-tab.sh`. See `~/.claude/docs/ghostty.md` for caveats. macOS + Ghostty only.

## Personal Scripts

- **One-off scripts** (swatches, debug probes, ad-hoc throwaways): write to `/tmp/`. Do not put them in `~/.aeby/scripts/`.
- **Long-lived scripts** (reusable tools, automation, anything referenced from docs or other scripts): live in `~/.aeby/scripts/`. They are allowed in cc-allow via the `aeby-scripts` alias (`path:$HOME/.aeby/scripts/**`).
- **Prototype everything in `/tmp/` first.** Only after a script has proven its value and shape should it be moved to `~/.aeby/scripts/`. This keeps the long-lived directory free of experimental clutter.

## Automation Over Suggestions

Never suggest the user manually do something without first attempting it. Be creative with tool use:

- **Web interactions**: Use Playwright MCP to navigate, click, fill forms, verify UI
- **Visual verification**: Read screenshots and images directly to inspect results
- **One-off scripts**: Write and execute temporary scripts for ad-hoc tasks
- **API calls**: Use curl/fetch to test endpoints directly
- **File inspection**: Read logs, outputs, and artifacts to verify behavior

If a tool fails or lacks permissions, then explain what manual step is needed.

## GitHub & Git Rules

See `~/.claude/docs/github.md` for GitHub CLI/API patterns (PR comment endpoints, reading review feedback).

- **Never push unless explicitly asked.** Words like "push", "open a PR", "ship it", "send it" count. Finishing a code change does NOT.
- **Never write PR comments or replies.** Do not use `gh pr comment`, `gh pr review`, or the GitHub API to post text on PRs. This includes `gh pr close --comment` — closing with an inline comment is still writing a comment. The only allowed post-push PR interaction is resolving threads via GraphQL `resolveReviewThread`.
- **Closed/resolved PR feedback does not exist.** When reading review threads, filter to unresolved only. Never read, reference, or act on resolved threads.
- **Never merge a PR without explicit instruction.**

## Worktree Merge to Main

When asked to "merge", "land", or move worktree changes "into" main (or equivalent phrasing):

1. **Build + test** on the worktree branch — all tests must pass
2. **Commit** on the worktree branch
3. **Land**: `worktree-land` (rebases onto main, cherry-picks onto main, resets the worktree branch)
4. **Rebuild on main** if the project CLAUDE.md documents a build command

"Landing" always means running `worktree-land` from the worktree directory. Do not manually cherry-pick or reset.

## npm link with fnm

See `~/.claude/docs/node.md` — use `npm link <path>` instead of global link when fnm auto-switches Node versions between repos. Includes mac-ui → olapui worktree setup steps.

## 1Password CLI

See `~/.claude/docs/1password.md` — pass `--account machinify.1password.com` to `op run` for olapui's `npmi` script.

## Taskwarrior

Taskwarrior is the to-do list manager. Phrases like "make a to-do item", "add a task", "remind me to", or "make a task" should be handled via `task add`. See `~/.claude/docs/taskwarrior.md` for CLI patterns, UDAs, contexts, and filtering.

## Jira CLI

When interacting with Jira issues, see `~/.claude/docs/jira.md` for auth setup (OAuth), common commands, and agent dispatch notes.

## Language & Tooling Docs

When working in a specific language, read the corresponding doc for linting, formatting, and package management conventions:

- Python (`uv`, `ruff`): See `~/.claude/docs/python.md`
- Rust (`cargo clippy`, `cargo fmt`): See `~/.claude/docs/rust.md`
- Lua (`stylua`, `lua_ls`): See `~/.claude/docs/lua.md`
- Shell / Bash / Zsh (`shellcheck`): See `~/.claude/docs/shell.md`
- GitHub Actions workflows (`actionlint`): See `~/.claude/docs/github-actions.md`
- JavaScript / TypeScript / Node (`eslint`, `prettier`, `biome`, `tsc`): See `~/.claude/docs/node.md`
- Taskwarrior (`task`): See `~/.claude/docs/taskwarrior.md`

For expanded testing guidance beyond the summary above, see `~/.claude/docs/testing.md`.

For expanded tmux guidance beyond the summary above, see `~/.claude/docs/tmux.md`.

## Planning

When planning complex changes or using plan mode, see `~/.claude/docs/planning.md` for the four-phase workflow, annotation cycles, and anti-patterns.

## Claude Code Settings & Hooks

When modifying Claude Code settings files, hooks, or permission config, see `~/.claude/docs/claude-settings.md` for structure, hook events, and the neovim parity principle.

## Session Tracking

When launching `claude` CLI from scripts or automation, see `~/.claude/docs/sessions.md` for env vars (`C_EPHEMERAL`, `C_SKIP`) that suppress session tracking in `c list`.

## cc-allow Permissions

When adding, modifying, or debugging `cc-allow.toml` permission rules, see `~/.claude/docs/cc-allow.md` for config hierarchy, rule syntax, pattern prefixes, specificity scoring, and `--debug` testing.

## Dotfiles

When editing files tracked by the dotfiles repo (`~/workspace/dotfiles`), see `~/.claude/docs/dotfiles.md` for the gather/sow sync workflow. Read `~/workspace/dotfiles/meadows.mjs` to determine which paths are tracked.

Secrets live in `~/.secrets.env` (cross-host; populated by `sync-secrets.sh`). Scripts needing a secret should source `~/.secrets.env` directly, not `~/.zshenv` — see `~/.claude/docs/dotfiles.md` §Secrets for the zsh/bash-host nuance.

## Information Stores

Personal data is split across purpose-built stores — Pinboard (web bookmarks + workflow queues), Giftwhale (wishlist), ITAD (game waitlist), Steam (game library), Notes (Johnny Decimal markdown), Taskwarrior (actionable tasks), InfluxDB (personal time-series DB), Grafana (dashboards over InfluxDB), ccq (query Claude Code session transcripts). Route items to the right store. For store map, auth, query patterns, and what-belongs-where: `~/.claude/docs/information-stores.md`.

**Grafana dashboards are server-authoritative.** Author via API or UI; do not version-control dashboard JSON locally.

## Cron

Device-agnostic scheduled jobs (API ingests, reports producing platform-independent output) run on `pi@stockholm`, not the Mac — the Mac sleeps and would leave gaps. Device-specific jobs stay on the Mac. See `~/.claude/docs/cron.md` for conventions, inventory, and how to add a new job.

## CLAUDE.md Maintenance

When adding, removing, or reorganizing docs files, or editing CLAUDE.md itself, see `~/.claude/docs/claude-md.md` for conventions on docs coverage, trigger conditions, inline vs. docs file decisions, and section structure.

## Permission-Aware Execution

At the start of a session (or when encountering permission friction), read the active settings files to understand what's allowed:

- `~/.claude/settings.json` (global)
- `.claude/settings.json` (project)
- `.claude/settings.local.json` (local overrides)

When multiple approaches can achieve the same goal:
- Prefer approaches that use tools/commands in the `allow` list
- Avoid approaches that require `ask` permissions when an allowed alternative exists
- Still request permission when the only viable approach requires it

**Examples:**
- If `git push` is allowed but `gh pr create` requires ask → use `git push` then explain how to create PR manually, or ask for permission
- If `npx prettier` is allowed but `npm run format` requires ask → use `npx prettier`
- If reading a file via `Read` tool is allowed but `cat` in Bash requires ask → use `Read` tool
