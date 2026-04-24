---
name: commit
description: "Propose structured commits for uncommitted changes. Use when the user says 'commit', wants to commit accumulated changes, or wants to structure uncommitted work into logical commits."
---

# Structured Commit

Analyze uncommitted changes, propose logical commit groupings, iterate with the user, then commit.

## Context

```
! git status --short
! git log --oneline -10
```

## Steps

### 1. Gather state

- `git diff` (unstaged changes)
- `git diff --cached` (staged changes)
- `git status --short` (untracked files)
- Read untracked files to understand their content
- `git log --oneline -10` to learn the repo's commit message style

### 2. Analyze and group

Read the diffs and infer logical groupings. Each group = one cohesive commit. Consider:

- **Cohesion**: files that change together (same feature across src/test/docs)
- **Type**: new feature, bug fix, refactoring, documentation
- **Order**: if commit B depends on commit A, A comes first

### 3. Propose

Present the plan as a numbered list:

```
## Proposed commits (in order)

### 1. <draft commit message>
- `path/to/file.ts` — <what changed>
- `path/to/other.ts` — <what changed>

### 2. <draft commit message>
- `path/to/file.ts` — <what changed>

---

Files left uncommitted: <list, or "none">
```

Match the repo's commit message style from `git log`.

### 4. Converse

Wait for the user to approve or correct. They may:
- Approve as-is
- Merge or split groups
- Reword messages
- Exclude files (leave uncommitted)
- Reorder commits

Iterate until approved.

### 5. Execute

On approval, for each commit in order:

```bash
git add <specific files>
git commit -m "$(cat <<'EOF'
<message>
EOF
)"
```

Report each resulting SHA.

### 6. Report

```
## Commits created

| # | SHA | Message |
|---|-----|---------|
| 1 | abc1234 | <message> |
| 2 | def5678 | <message> |

Files left uncommitted: <list, or "none">
```

## Defaults

These apply unless the user explicitly overrides during iteration:

- **Don't push.** Commits are local only.
- **Don't amend** existing commits.
- **Don't use `--no-verify`** to skip hooks.
- **Stage specific files** — prefer named paths over `git add -A` or `git add .`.
- If a pre-commit hook fails, fix the issue and create a new commit.
