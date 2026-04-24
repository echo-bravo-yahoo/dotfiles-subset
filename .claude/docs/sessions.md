# Session Tracking Env Vars

When launching `claude` CLI from scripts, automation, or benchmarks, set one of these env vars to prevent the session from appearing in `c list`.

## `C_EPHEMERAL=1`

Skips session registration in `~/.c/index.toml`. The session runs normally — all other hooks (post-bash, notifications, session-end) still fire — but the session is never written to the index.

**When to use:** Any programmatic invocation of `claude` that doesn't need to be tracked: AMQ dispatch workers, benchmark harnesses, test scripts, `Bash` tool shelling out to `claude`.

**Source:** `~/workspace/c/src/hooks/session-start.ts` — checked at lines 106 and 243.

```bash
# Script / automation
export C_EPHEMERAL=1
claude 'do something'

# Inline
C_EPHEMERAL=1 claude 'do something'
```

The CLI equivalent for manual one-offs: `c new --ephemeral`.

## `C_SKIP=1`

Short-circuits ALL `c` hook processing — session-start, session-end, notifications, post-bash, stop. Nothing fires.

**When to use:** CI, performance-sensitive contexts, or situations where no `c` features are needed at all. More aggressive than `C_EPHEMERAL` — use only when hook side effects are unwanted.

**Source:** `~/workspace/c/src/hooks/index.ts` — checked at line 73.

## Fork Detection

`session-fork-info <session-id>` detects whether a session is a fork and identifies its parent. Exit 0 = fork (prints `parent=<id>` and `fork_time=<ts>`), exit 1 = not a fork, exit 2 = error.

```bash
session-fork-info 949839a6-698c-4ad2-9398-7e577ed92811
# parent=aa4a7b13-6ed7-46fc-a083-3ba76e9d85f1
# fork_time=2026-04-15T16:51:50.242Z
```

**How it works:** Forked sessions copy the parent's message history, so message UUIDs are shared. The script checks whether the session's first UUID exists in any sibling session file (first 20 lines, O(1) per file). Direction is determined by creation time — earlier session is the parent.

**Caveats:** With chained forks (A→B→C), running on C may report A instead of B as the parent — it finds *an* ancestor, not necessarily the direct parent.

## Rule of thumb

Any code path that calls `claude` CLI programmatically should set `C_EPHEMERAL=1` unless there's a specific reason to track the session. This includes:

- AMQ dispatch (`~/.claude/scripts/amq-dispatch`)
- Benchmark / comparison harnesses
- Test scripts that spawn `claude` processes
- `Bash` tool invocations that shell out to `claude`
