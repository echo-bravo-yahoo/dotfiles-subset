# Agent Messaging (AMQ)

Protocol for agents participating in AMQ-coordinated workflows. This doc is pipeline-agnostic — the specific agent roles and permissions come from the repo's `.claude/amq/pipeline.toml`.

## Identity

| Variable | Source | Description |
|---|---|---|
| `AM_ME` | Environment | This agent's handle |
| `AM_ROOT` | Environment | Path to `.agent-mail/` root |
| `AM_THREAD` | Environment | Thread ID for the current feature (e.g., `topic/MAC-12345`) |

## Checking for Messages

Before starting work and between major steps, check for one incoming message:

```bash
amq drain --me $AM_ME --include-body --root $AM_ROOT --limit 1
```

Process one message at a time. If it changes the current task (new assignment, review feedback, question), address it before continuing. If informational (status update from another agent), note it and continue.

To peek without consuming:

```bash
amq list --me $AM_ME --new --root $AM_ROOT
```

## Sending Messages

### Progress update

When a milestone is reached:

```bash
amq send --me $AM_ME --to <recipient> --kind status \
  --thread $AM_THREAD --subject "<one-line summary>" \
  --labels "cost:<cumulative $>,elapsed:<minutes>m" \
  --body "<details: files changed, decisions made, test results>"
```

Always include cost and elapsed labels for circuit breaker tracking.

### Asking a question

When blocked or needing input:

```bash
amq send --me $AM_ME --to <recipient> --kind question \
  --thread $AM_THREAD --subject "<the question>" \
  --body "<context needed to answer>"
```

Continue with other work if possible. Check inbox later for the answer.

### Proposing an approach

```bash
amq send --me $AM_ME --to ashton --kind brainstorm \
  --thread $AM_THREAD --subject "<proposal title>" \
  --body "<what, why, tradeoffs>"
```

### Assigning work

```bash
amq send --me $AM_ME --to <agent> --kind todo \
  --thread $AM_THREAD --subject "<task title>" \
  --body "<specific instructions, file paths, acceptance criteria>"
```

### Requesting review

When code is committed and tests pass:

```bash
amq send --me $AM_ME --to reviewer --kind review_request \
  --thread $AM_THREAD --subject "Ready for review: <feature>" \
  --body "<worktree path, branch name, what changed, how to test>"
```

### Sending review feedback

Approved:

```bash
amq send --me $AM_ME --to ashton --kind decision \
  --thread $AM_THREAD --labels "approved" \
  --subject "<feature> approved" \
  --body "<summary, any notes>"
```

Changes needed:

```bash
amq send --me $AM_ME --to coder --kind review_response \
  --thread $AM_THREAD --labels "rejected" \
  --subject "Changes requested: <feature>" \
  --body "<specific feedback: what, where, why>"
```

### Requesting verify gate

When implementation is complete and ready for deterministic checks:

```bash
amq send --me $AM_ME --to dispatcher --kind status \
  --thread $AM_THREAD --labels "verify-request" \
  --subject "Verify: <feature>"
```

Wait for `verify-pass` or `verify-fail` in inbox before proceeding.

### Circuit breaker escalation

Before rejecting, check the thread for cumulative cost/elapsed labels. If cost exceeds the pipeline's `max_cost` or elapsed exceeds `max_elapsed`, escalate instead:

```bash
amq send --me $AM_ME --to ashton --kind decision \
  --priority urgent --thread $AM_THREAD --labels "circuit-break" \
  --subject "<feature> escalated — cost/time exceeded" \
  --body "<what failed, cumulative cost, elapsed time>"
```

## Thread Convention

All messages for a feature share one thread: `$AM_THREAD` (typically `topic/<slug>`).

Any agent can reconstruct the full conversation by scanning `inbox/cur/` and `outbox/sent/` directories.

## Sessions

AMQ sessions provide isolation for concurrent pipelines. Each session is a subdirectory under the base `.agent-mail/` root with its own `agents/`, `meta/`, and `threads/`.

### How sessions work

| Concept | Mechanism |
|---------|-----------|
| Create a session | `amq coop exec --session <name>` or `amq init --root .agent-mail/<name>` |
| Session on disk | `.agent-mail/<name>/agents/<handle>/inbox/...` |
| Default session | `collab` (when no `--session` or `--root` given to `coop exec`) |
| Agent identity | Bare handles (`coder`, `tester`) — scoped to the session root |
| Cross-session send | `amq send --to <handle> --session <target>` |

`--session <name>` is shorthand for `--root .agent-mail/<name>`.

### Pipeline isolation

Each dispatched pipeline runs in its own session (e.g., `.agent-mail/diff/`). Agent handles like `coder` and `tester` are reused across pipelines without collision because each session has independent mailboxes.

```
.agent-mail/
  collab/agents/ashton/...       # user session
  diff/agents/coder/...          # pipeline "diff"
  diff/agents/tester/...
  auth/agents/coder/...          # pipeline "auth" (concurrent, no collision)
```

### Sending to the user from a pipeline

Agents inside a pipeline session send to the user's session with `--session`:

```bash
amq send --me $AM_ME --to ashton --session collab \
  --kind decision --thread $AM_THREAD --subject "approved"
```

Without `--session`, the message stays in the pipeline's own session and the user won't see it.

### Draining from a session

The user drains from their own session:

```bash
amq drain --me ashton --root .agent-mail/collab --include-body
```

Or lists across sessions by specifying roots explicitly.

### Rules for sessions

- Within a session: use bare `--to <handle>`. No `--session` flag needed.
- To the user: always include `--session <user_session>` (typically `collab`).
- Never override `AM_ROOT` or `AM_ME` when running inside `coop exec` — the session env is authoritative.
- Thread IDs (`$AM_THREAD`) are global — they work across sessions for traceability.

## Audit Trail

Messages are never deleted. After `drain`:
- `inbox/new/` → `inbox/cur/` (consumed, still on disk)
- `outbox/sent/` retains the sender's copy

Reconstruct chronologically:

```bash
cat .agent-mail/agents/*/outbox/sent/*.md | sort
```

## Rules

- Never push to remote. The human handles git push and PR creation.
- Never transition phases without assignment from the human or pipeline routing.
- Always include the thread ID (`$AM_THREAD`) in every message.
- Always include cost/elapsed labels in status messages.
- Check inbox between major steps (`drain --limit 1`).
- When blocked, send `kind:question` rather than guessing.
- Keep message bodies concise — file paths, line numbers, command outputs.
- The plan message (first in the thread) is the source of truth for scope.
- Permission boundaries are enforced by the session's cc-allow config. Do not attempt to write files outside allowed paths.
- When sending to the user (`ashton`), include `--session collab` (or the configured user session).
