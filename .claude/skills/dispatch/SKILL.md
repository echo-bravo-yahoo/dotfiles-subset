---
name: dispatch
description: "Dispatch work to a multi-agent AMQ workflow. Accepts a plan file, current session plan, or inline goal."
argument-hint: "<feature-slug> [plan-file-or-goal]"
---

# Dispatch

Launch a multi-agent pipeline using AMQ messaging, configured by the repo's `.claude/amq/pipeline.toml`.

## Context

```
! [ -f .claude/amq/pipeline.toml ] && echo "pipeline.toml found" || echo "NO pipeline.toml — create .claude/amq/pipeline.toml first (see ~/.claude/docs/amq-pipeline-schema.md)"
! amq --version 2>/dev/null || echo "AMQ not installed — brew install avivsinai/tap/amq"
```

## Steps

### 1. Parse arguments

The argument is `<slug> [plan-source]`. Parse it:

- If two arguments and the second is a file path that exists: **plan file mode**
- If one argument and `.claude/plans/*.md` exists from the current session: **current plan mode**
- If two arguments and the second is a short string (not a file path): **inline goal mode**
- If one argument and no session plan exists: ask the user for a plan or goal

### 2. Resolve the plan

**Plan file mode:** Read the file. This is the plan.

**Current plan mode:** Read the most recent `.claude/plans/*.md` file. This is the plan.

**Inline goal mode:** The goal is too vague to dispatch directly. Before dispatching:
1. Enter plan mode or use an Explore agent to investigate the codebase
2. Iterate with the user on the approach
3. Once the user approves, write the plan to a temp file and proceed

### 3. Verify prerequisites

- `.claude/amq/pipeline.toml` must exist. If not, show the user a minimal example from `~/.claude/docs/amq-pipeline-schema.md` and stop.
- `amq` CLI must be installed.
- Must be in a git repository.
- Must be in a tmux session (agents are spawned as tmux windows).

### 4. Write the plan to a file

If the plan isn't already a file (e.g., inline goal mode), write it to `.claude/plans/<slug>.md`.

### 5. Dispatch

Run the dispatch script:

```bash
~/.claude/scripts/amq-dispatch "<slug>" --plan "<plan-file>" --config .claude/amq/pipeline.toml
```

This script:
- Initializes the AMQ mailbox root
- Creates worktrees per pipeline config
- Generates cc-allow permission files per agent
- Spawns first-wave agents (those subscribing to `todo`) as tmux windows
- Sends the plan as `kind:brainstorm` to the thread
- Sends `kind:todo` to first-wave agents
- Starts `amq-notify` for OS notifications
- Runs the route evaluator (foreground — watches for messages and spawns later-wave agents on demand)

**The dispatch script runs in the foreground** as the route evaluator. It blocks until Ctrl+C. To run it in the background:

```bash
~/.claude/scripts/amq-dispatch "<slug>" --plan "<plan-file>" --config .claude/amq/pipeline.toml &
```

### 6. Report

After dispatch, report to the user:
- Thread ID (e.g., `topic/MAC-12345`)
- Which agents were spawned and where
- How to monitor: `amq list --me ashton --new --root <root>`
- How to drain: `amq drain --me ashton --include-body --root <root>`
- The route evaluator is running — agents will be spawned on demand as messages flow
- The user will get OS notifications for decisions and circuit breaks

## Error Handling

| Problem | Action |
|---------|--------|
| No pipeline.toml | Show example, stop |
| amq not installed | Tell user: `brew install avivsinai/tap/amq` |
| Not in git repo | Stop with error |
| Not in tmux | Stop with error — agents require tmux windows |
| Plan file not found | Ask user for path |
| Dispatch script fails | Show stderr, stop |
