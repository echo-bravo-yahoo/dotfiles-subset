---
name: gather
description: "Sync edited dotfiles to the backup repo and commit."
argument-hint: "[commit message]"
---

# Gather Dotfiles

Sync tracked dotfiles from the filesystem into the dotfiles backup repo and commit.

## Context

```
! cd ~/workspace/dotfiles && git status --short 2>/dev/null | head -20
```

## Steps

1. Run gather from the dotfiles repo root:
   ```bash
   cd ~/workspace/dotfiles && wildflower gather
   ```

2. Check for changes:
   ```bash
   cd ~/workspace/dotfiles && git status --short
   ```
   If clean, report "Dotfiles already in sync" and stop.

3. Show the diff summary:
   ```bash
   cd ~/workspace/dotfiles && git diff --stat
   ```

4. Stage and commit. If an argument was provided, use it as the commit message. Otherwise, generate one from the changed files.

   Commit message conventions (from repo history):
   - Prefix with subsystem: `nvim:`, `zsh:`, `tmux:`, `macos:`, `claude:`, etc.
   - Multiple subsystems: use a general description or list prefixes (`zsh, tmux: ...`)
   - Imperative mood, no trailing period

   ```bash
   cd ~/workspace/dotfiles && git add -A && git commit -m "<message>"
   ```

5. Report the commit hash and changed file count. Do NOT push.
