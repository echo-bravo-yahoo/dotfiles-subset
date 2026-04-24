# AMQ Pipeline Schema

Per-repo configuration for multi-agent workflows. Lives at `.claude/amq/pipeline.toml`. If the file doesn't exist, the framework is not active.

## Minimal Example

```toml
version = "1"

[pipeline]
name = "default"

[[routes]]
on = { kind = "decision", labels = ["approved"] }
actions = ["notify"]

[[agents]]
name = "coder"
subscribes_to = ["todo"]

[[agents]]
name = "reviewer"
subscribes_to = ["review_request"]
```

## Full Example

```toml
version = "1"

[pipeline]
name = "default"
thread_prefix = "topic"

[pipeline.circuit_breaker]
max_cost = 15.0
max_elapsed = 60

[[routes]]
on = { kind = "decision", labels = ["approved"] }
actions = ["notify", "agent:reflector"]

[[routes]]
on = { kind = "decision", labels = ["circuit-break"] }
actions = ["notify"]

[[agents]]
name = "tester"
model = "sonnet"
subscribes_to = ["todo"]

[agents.worktree]
mode = "shared"
name = "impl"

[agents.permissions.write.allow]
paths = ["path:tests/**", "path:test/**", "path:*.test.*", "path:*.spec.*"]

[agents.permissions.write.deny]
paths = ["path:src/**", "path:js/**", "path:css/**"]

[agents.permissions.bash.deny]
commands = ["git push", "npm publish"]

[agents.instructions]
startup = "Read the plan, then write tests that define the acceptance criteria."
on_complete = "Send kind:todo to coder with test file paths."

[[agents]]
name = "coder"
model = "opus"
subscribes_to = ["todo"]

[agents.worktree]
mode = "shared"
name = "impl"

[agents.permissions.write.allow]
paths = ["path:src/**", "path:js/**", "path:css/**", "path:lib/**"]

[agents.permissions.write.deny]
paths = ["path:tests/**", "path:test/**", "path:*.test.*", "path:*.spec.*"]

[agents.permissions.bash.deny]
commands = ["git push", "npm publish"]

[agents.instructions]
startup = "Read the plan and tester's status. Implement the feature, making tests pass."
on_complete = "Send kind:review_request to reviewer."
verify = ["run:npx tsc", "run:npx prettier --check .", "run:npm test"]

[[agents]]
name = "reviewer"
agent_def = "reviewer"
model = "opus"
subscribes_to = ["review_request"]

[agents.worktree]
mode = "none"

[agents.permissions.write.deny]
paths = ["path:**"]

[agents.instructions]
startup = "Get the worktree path from the review request. Run git diff independently. Run tests."
review_against = [".claude/rules/*.md"]

[[agents]]
name = "reflector"
agent_def = "reflector"
model = "sonnet"
subscribes_to = ["decision"]

[agents.worktree]
mode = "none"

[agents.permissions.write.deny]
paths = ["path:**"]

[agents.instructions]
startup = "Read the full thread. Propose improvements to Claude Code config."
on_complete = "Send proposals as kind:brainstorm to human."
```

## Field Reference

### `[pipeline]`

| Field | Type | Default | Description |
|---|---|---|---|
| `name` | string | `"default"` | Pipeline identifier |
| `thread_prefix` | string | `"topic"` | Thread IDs: `<prefix>/<slug>` |
| `circuit_breaker.max_cost` | float | `15.0` | USD — escalate if exceeded |
| `circuit_breaker.max_elapsed` | int | `60` | Minutes — escalate if exceeded |

### `[[routes]]`

Event→action fan-out. Evaluated by the dispatch runtime, not by agents.

| Field | Type | Description |
|---|---|---|
| `on.kind` | string | Match messages with this `kind` |
| `on.labels` | array | Match messages containing ALL these labels |
| `on.from` | string | (optional) Match from specific sender |
| `actions` | array | All fire in parallel |

**Actions support interpolation** from the triggering message:

| Variable | Source |
|---|---|
| `{from}` | Message sender handle |
| `{to}` | Message recipient(s) |
| `{subject}` | Message subject line |
| `{kind}` | Message kind |
| `{thread}` | Thread ID |
| `{body}` | Message body |
| `{labels}` | Comma-separated labels |
| `{worktree}` | Worktree path of the sending agent |
| `{branch}` | Git branch of the sending agent |

**Action types:**

| Action | What it does |
|---|---|
| `"notify"` | OS notification via amq-notify |
| `"agent:<name>"` | Deliver message to agent inbox; spawn agent if not running |
| `"run:<command>"` | Execute command (interpolated). Message body on stdin. |
| `"amq:<kind>:<to>"` | Send new AMQ message. Body forwarded from trigger. |

Multiple routes can match the same message — all fire.

### `[[agents]]`

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | AMQ handle |
| `model` | string | no | `"opus"`, `"sonnet"`, `"haiku"` |
| `agent_def` | string | no | Name of `.claude/agents/<name>.md` to load. Empty = inline only. |
| `subscribes_to` | array | yes | AMQ `kind` values that activate this agent |

Agents subscribing to `"todo"` are spawned at dispatch time. Others are spawned on-demand by the route evaluator when a matching message appears.

### `[agents.worktree]`

| Field | Type | Default | Description |
|---|---|---|---|
| `mode` | string | `"none"` | `"shared"`, `"dedicated"`, or `"none"` |
| `name` | string | — | For shared: worktree name. Agents with same name share one worktree. |

### `[agents.permissions]`

Raw cc-allow TOML. Written verbatim to a session config for the agent. Full cc-allow syntax: `[write.allow]`, `[write.deny]`, `[bash.allow]`, `[bash.deny]`, `[read.deny]`, etc.

### `[agents.instructions]`

| Field | Type | Description |
|---|---|---|
| `startup` | string | Prompt instruction after assignment arrives |
| `on_complete` | string or action[] | String = LLM instruction. Array = deterministic runtime actions. |
| `verify` | action[] | Deterministic. Runtime executes each `"run:<cmd>"`. Agent cannot bypass. |
| `review_against` | array of globs | Files for reviewer to check |

**Verify protocol:** Agent sends `kind:status labels:verify-request` to dispatcher. Runtime runs commands. Sends `verify-pass` or `verify-fail` (with output) back. Agent retries on failure. Circuit break after 3 failures.

**`on_complete` dual type:**
```toml
# LLM decides (flexible):
on_complete = "Send kind:todo to coder with test file paths."

# Runtime executes (deterministic):
on_complete = ["amq:todo:coder"]
```
