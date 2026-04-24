# Dotfiles Sync

Dotfiles are managed via `wildflower` in `~/workspace/dotfiles`. Tracked paths are declared in `~/workspace/dotfiles/meadows.mjs` — read that file for the authoritative list; do not hardcode.

## Architecture

Multiple Claude Code sessions (and multiple hosts) edit this repo concurrently. The sync flow is layered so no single actor needs to remember the right sequence — each component has a narrow, enforced responsibility.

| Component | Responsibility | Does not |
|-----------|----------------|----------|
| **Watcher daemon** (`~/.aeby/scripts/dotfiles-watcher.sh`) | Auto-run `wildflower gather` on every fs change to tracked home paths | Stage, commit, push |
| **LLM (Claude)** | Selective stage + commit after editing a tracked home file | Ever run `git add -A`; ever run `git pull` directly |
| **Update script** (`~/.aeby/scripts/dotfiles-update.sh`) | `gather → stash → pull --rebase → pop → sow` + write freshness marker | Commit, push |
| **Pre-push hook** (`.git/hooks/pre-push`, symlinked to `~/.aeby/scripts/dotfiles-prepush-hook.sh`) | Refuse push unless the marker proves the update script ran since the last fetch | Anything else |

Enforcement: `~/.config/cc-allow.toml` denies bare `wildflower gather|sow|till`, `git -C ~/workspace/dotfiles pull`, and `git -C ~/workspace/dotfiles add -A`. The sanctioned entry points under `~/.aeby/scripts/` are allowed.

Accepted tradeoffs (by design, not mitigated):
- Watcher may miss edits under load / rapid rename-create.
- Two LLM sessions may race on the same path; last-writer-wins on the blob.
- Watcher may gather mid-pull; accepted race.
- Dirty state may accrue in the backup repo; no automatic sweep.

## Which files are tracked

Read `~/workspace/dotfiles/meadows.mjs`. Filters under `~/.claude` use an allowlist pattern (`!**/*` then explicit includes) — **new files created in `~/.claude/` that aren't on the allowlist won't sync**. Audit the allowlist when adding a new skill, doc, or script.

## After editing a live dotfile

The watcher handles gather automatically. To commit your edit:

1. Confirm the watcher picked it up: `git -C ~/workspace/dotfiles status --short` shows the mirrored `meadows/~~/...` path as dirty.
2. Stage only that path. **Never `git add -A` or `git add .` in this repo** — cc-allow denies it, and it would sweep up other sessions' or hosts' work.
3. Commit with the format in §Commit message format below.

If `git status` is clean but your edit should have been tracked, check the watcher log (`tail -20 ~/.aeby/logs/dotfiles-watcher.log`). If the watcher missed the event, use the `/gather` emergency-checkpoint skill.

## Pull workflow

`~/.aeby/scripts/dotfiles-update.sh` is the **only** way to pull. Never `git pull` in the dotfiles repo directly — cc-allow denies it.

Steps the script performs:
1. **`wildflower gather`** — capture any live home edits so they're not undone by the incoming pull.
2. **`git stash push -u`** — park any uncommitted repo state (including what gather just produced) so pull has a clean tree.
3. **`git pull --rebase origin main`** — fetch + rebase local commits onto upstream.
4. **`git stash pop`** — replay the parked state on top of the new HEAD.
5. **`wildflower sow`** — deliver the merged state back to the home directory.
6. **Write marker** — record `origin/main`'s current SHA to `.last-update`.

Each step exists to prevent a specific failure:
- Skip gather → home edits are undone by the pull.
- Skip stash → pull --rebase refuses on a dirty tree.
- Skip sow → home is stale relative to backup.
- Skip marker → pre-push hook stays unsatisfied; push is refused.

The script exits 2 on any failure with remediation on stderr. Exit 0 means the marker is fresh and the pre-push hook will allow a push.

## Commit message format

```
<subsystem>: <description>

<optional body prose>

<bare session ID>
```

- **Subject**: subsystem prefix (`nvim:`, `zsh:`, `tmux:`, `claude:`, `macos:`, etc.) + concise description, imperative mood, no trailing period.
- **Body** (optional): prose description of the why.
- **Last line of the body**: the Claude Code session ID as a bare string. No label, no "Session:" prefix, no "claude" word, no LLM attribution — just the ID. Claude Code does not expose the ID via env var; derive it at commit time from the most recently modified transcript in the current project's dir, e.g. `ls -t ~/.claude/projects/$(pwd | sed 's|/|-|g')/*.jsonl 2>/dev/null | head -1 | xargs -I {} sh -c 'head -1 "{}" | jq -r .sessionId'`. If that fails, omit the ID rather than guessing.

Example:
```
claude: rewrite CLAUDE.md §Dotfile Syncing

Folds in the watcher-driven architecture. See plan at
~/.claude/plans/additionally-the-reason-this-sprightly-hickey.md.

9f3c-8b2a-4d15-a7f2-0c6e
```

The bare-ID trailer lets post-hoc diagnosis find which session authored which commit via `git log --grep=<partial-id>` and reflog — important when commits get orphaned by rebases across sessions.

## Recovery

### Update script failed mid-flow

Read its stderr. Each exit-2 path names the remediation. Common cases:

- **`git pull --rebase` conflict**: resolve with `git rebase --continue` or `git rebase --abort`, then re-run the update script.
- **`git stash pop` conflict**: fix conflict markers in the working tree, `git add` the resolved paths, `git stash drop`, then re-run the script.
- **`wildflower sow` failed**: home is out of sync with backup; diagnose the sow error first, then re-run the script.

### Pre-push hook refused the push

The marker `.last-update` doesn't match current `origin/main`, which means someone (another host, another session) pushed since the last local update. Run `~/.aeby/scripts/dotfiles-update.sh` to pull-reconcile, then retry the push.

Override: `git push --no-verify`. Only use this if you genuinely know you want to overwrite upstream — usually you don't.

### Orphaned commit in reflog

If a commit appears to have vanished from `main`, check the reflog:

```bash
git -C ~/workspace/dotfiles reflog -30
git -C ~/workspace/dotfiles log --all --oneline -30
```

Commits authored by a session-ID trailer are searchable:

```bash
git -C ~/workspace/dotfiles log --all --grep=<partial-session-id>
```

Cherry-pick any orphan forward:

```bash
git -C ~/workspace/dotfiles cherry-pick <orphan-sha>
```

## Watcher: what it is, install, status, uninstall

### What it does

`~/.aeby/scripts/dotfiles-watcher.sh` is a long-running daemon (started by launchd on macOS, systemd user service on Linux/WSL) that watches the home-directory roots declared in `~/workspace/dotfiles/meadows.mjs`. On any fs change event, it debounces ~500ms and runs `wildflower gather` from inside the dotfiles repo, so the backup mirror stays current with live home edits. It never stages, commits, or pushes — those remain the LLM's responsibility.

Logs: `~/.aeby/logs/dotfiles-watcher.log` (script diagnostics + wildflower output), `~/.aeby/logs/dotfiles-watcher.out.log` (service manager stdout), `~/.aeby/logs/dotfiles-watcher.err.log` (service manager stderr).

### Install (per host, once)

```bash
~/.aeby/scripts/install-dotfiles-watcher.sh
~/.aeby/scripts/install-dotfiles-hooks.sh
```

Both installers are idempotent. They require `fswatch` on PATH (`brew install fswatch` on macOS; `apt install fswatch` on Debian/Ubuntu).

### Is it running?

**macOS**:
```bash
launchctl list | grep dotfiles-watcher
# Output format: <PID> <LAST_EXIT> dev.aeby.dotfiles-watcher
# A PID (not "-") in the first column means it's running.
# Second column is the last exit code: 0 (or "-") is healthy; non-zero means it died.
```

**Linux / WSL**:
```bash
systemctl --user status dotfiles-watcher.service
```

**Either platform — quick sanity check**: tail the log and see if recent events have been coalesced into `gather OK` lines:
```bash
tail -20 ~/.aeby/logs/dotfiles-watcher.log
```

### Start / restart

The installer is also the "start" command — re-running it unloads any existing instance and loads a fresh one.

```bash
~/.aeby/scripts/install-dotfiles-watcher.sh
```

### Uninstall

**macOS**:
```bash
launchctl unload ~/Library/LaunchAgents/dev.aeby.dotfiles-watcher.plist
rm ~/Library/LaunchAgents/dev.aeby.dotfiles-watcher.plist
```

**Linux / WSL**:
```bash
systemctl --user disable --now dotfiles-watcher.service
rm ~/.config/systemd/user/dotfiles-watcher.service
```

**Remove pre-push hook**:
```bash
rm ~/workspace/dotfiles/.git/hooks/pre-push
```

## Secrets (`~/.secrets.env`)

Secrets live in `~/.secrets.env`, generated by `sync-secrets.sh` in the dotfiles repo.

- **Cross-host.** The file is created on **every** host that runs `sync-secrets.sh` — macOS, most Linux, WSL. Contents are identical across hosts. There is no Mac-only "special" secrets file; the same 1Password fetches populate the same env vars everywhere.
- **Staleness.** `sync-secrets.sh` only runs when invoked; if a new secret was added to the script (e.g., a new `export …` line), hosts that haven't re-run it won't have that var. Symptom: script errors like "API auth failed" / empty token. Fix: `bash ~/workspace/dotfiles/sync-secrets.sh` on the affected host.
- **Sourcing mechanism differs, not the file.** Most Mac/Linux hosts run zsh and pick `~/.secrets.env` up via `~/.zshenv`. Minimal embedded Linux hosts like `pi@stockholm` run bash and don't read `.zshenv` — so shells there don't auto-source secrets. This is a shell-config detail, not a platform one.
- **Scripts should source `~/.secrets.env` directly,** not `~/.zshenv`, so they work on any shell. The `~/.zshenv` path is silently broken on bash-only hosts.

```bash
# in a script that needs a secret:
[[ -f "$HOME/.secrets.env" ]] && source "$HOME/.secrets.env"
```

Adding a new secret: extend `sync-secrets.sh` with an `export FOO="$(fetch foo_field)"`, add `foo_field` to the 1Password "Dotfiles Secrets" item, then re-run `sync-secrets.sh` on every host that needs it.
