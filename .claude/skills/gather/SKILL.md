---
name: gather
description: "Emergency-checkpoint sync for dotfiles. FALLBACK ONLY — the watcher handles routine gather. Use when the watcher is down or the user explicitly asks for a manual checkpoint."
argument-hint: "[commit message]"
---

# Gather Dotfiles (fallback)

**This skill is a fallback, not the default path.** Routine gather is handled by the watcher daemon (launchd on macOS, systemd user service on Linux/WSL). Direct `wildflower gather` is denied by cc-allow.

Use this skill only when:
- The watcher daemon is down or you suspect it missed events.
- The user explicitly asks for a manual sync/checkpoint.
- You need to commit a known-dirty state discovered via `git status`.

For routine workflow, see `~/.claude/CLAUDE.md §Dotfile Syncing` and `~/.claude/docs/dotfiles.md`.

## Context

```
! cd ~/workspace/dotfiles && git status --short 2>/dev/null | head -20
```

## Steps

### 1. Verify the watcher isn't the right answer

Check the watcher log first — a recent gather line means the watcher is healthy and this skill isn't needed:

```bash
tail -5 ~/.aeby/logs/dotfiles-watcher.log 2>/dev/null
```

If the last gather-OK line is recent (within the last few minutes) and `git status` in the dotfiles repo still shows the expected edit, stop — the issue isn't with gather.

### 2. Manual gather

Since cc-allow denies bare `wildflower gather`, invoke via the emergency helper (a short pass-through). If that doesn't exist yet, ask the user to run `wildflower gather` themselves in a shell they control — never override the permission denial programmatically.

### 3. Inspect what changed

```bash
cd ~/workspace/dotfiles && git status --short
cd ~/workspace/dotfiles && git diff --stat
```

If clean, report "Dotfiles already in sync" and stop.

### 4. Stage narrowly and commit

**Never `git add -A` in this repo** — cc-allow denies it, and it would sweep up other sessions' work.

Stage only the specific `meadows/~~/...` path(s) that mirror files this session edited. If the dirty state includes paths this session did not edit, stop and ask the user — those are another session's or another host's work.

```bash
cd ~/workspace/dotfiles && git add <specific pathspec>
```

Commit message format: subject `<subsystem>: <description>`, blank line, optional prose, blank line, then bare `$CLAUDE_SESSION_ID` as the last line of the body. Example:

```
claude: restore CLAUDE.md dotfile-sync section

9f3c-8b2a-4d15-a7f2-0c6e
```

```bash
git -C ~/workspace/dotfiles commit -m "$(printf '%s\n\n%s\n' '<subject>' "$CLAUDE_SESSION_ID")"
```

### 5. Push (only after the update script has run)

If there's anything to push, the pre-push hook will refuse unless `~/.aeby/scripts/dotfiles-update.sh` has run since the last fetch. Do not `--no-verify` without the user's explicit say-so.

If the hook refuses, run the update script first:

```bash
~/.aeby/scripts/dotfiles-update.sh
```

Then retry the push.

### 6. Report

- Commit hash
- Files committed (scoped to this session's edits)
- Whether push succeeded
