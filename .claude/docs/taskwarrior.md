# Taskwarrior (`task`)

Taskwarrior is the to-do list / task queue manager. Requests like "make a to-do item", "add a task", "remind me to", or "make a task" should be handled via `task add`.

## CLI Basics

```bash
task add "description"                    # Add task (default project: personal)
task add project:work "description"       # Add work task
task <id> modify priority:H               # Modify task
task <id> done                            # Complete task
task <id> delete                          # Delete task
task <id> annotate "note"                 # Add annotation
task <id> start                           # Mark as active
task <id> stop                            # Unmark active
```

## UDAs (User-Defined Attributes)

UDAs are single-value only — no array/list type exists in taskwarrior.

| UDA | Type | Indicator | Purpose |
|-----|------|-----------|---------|
| `link` | string | ⟛ | External URL (documentation, Slack permalink, etc.) |
| `jira` | string | J | Jira ticket URL |
| `difficulty` | string | — | `trivial`, `easy`, `medium`, `hard` |
| `reviewed` | date | — | Last review date (used by `_reviewed` report) |

Usage: `task add "description" link:"https://..." jira:"https://machinify.atlassian.net/browse/MAC-123"`

## Projects

Default project: `personal`. Work tasks use `project:work`.

Key project prefixes: `work`, `personal`, `hobby.*`, `computer.*`, `fgc.*`, `blog`, `fun`, `home`, `iot`, `keeb`, `music`, `photo`, `presence`, `selfhosted`.

## Tags

**Do not create new tags.** Only use tags that already exist on at least one other task. Run `task tags` to see the current tag list before adding any tag.

## Contexts

```bash
task context work       # Read: (pro:work or +bit), Write: pro:work
task context home       # Read: pro.not:work
task context typical    # Read: excludes entertainment tags
task context none       # Clear context
```

The `work` write context auto-sets `project:work` on new tasks.

## Urgency

- `tags.coefficient=0` — tags don't affect urgency
- `+blockedish` tag: -5 urgency (soft block, not a formal `depends:`)

## Key Reports

```bash
task project:work next          # Work tasks sorted by urgency
task project:work list          # All pending work tasks
task +today pro:work list       # Today's focus items
task project:work +ACTIVE list  # Currently active work tasks
```

## Recurrence

`recurrence=off` on this device due to a [multi-client sync duplication bug](https://github.com/GothenburgBitFactory/taskwarrior/issues/1649). Only one synced device should have `recurrence=on`.

Tasks with `recur:` attributes **can still be created** on any device. The primary device (with `recurrence=on`) generates instances, which sync back.

```bash
task add project:work recur:weekly due:thursday "Update Jira statuses"
task sync   # Push to server so primary device picks it up
```

Common recurrence intervals: `daily`, `weekly`, `biweekly`, `monthly`, `quarterly`, `yearly`.

## Sync

```bash
task sync    # Sync to/from remote server
```

Server: configured in `.taskrc` (taskchampion-sync-server with encryption).

## Filtering

```bash
pro:work                    # Project filter
+tag                        # Tag filter
entry:today                 # Created today
entry.before:now-30d        # Created more than 30 days ago
end.after:today             # Completed today
due:                        # Has a due date
due.before:tomorrow         # Due today or overdue
scheduled.before:now        # Scheduled and ready
wait:                       # Waiting (hidden until wait date)
status:pending              # Pending tasks (default for most reports)
```

Combine filters: `task pro:work +today priority:H list`
