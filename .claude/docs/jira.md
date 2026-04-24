# Jira CLI (`acli`)

Atlassian official CLI. Installed via `brew tap atlassian/homebrew-acli && brew install acli`.

## Auth

Uses OAuth — no API tokens or 1Password integration needed.

```bash
acli jira auth login    # One-time browser-based OAuth login
acli jira auth status   # Verify auth / current user
```

OAuth persists across sessions. Agents inherit the auth automatically — no env var export needed in agent prompts.

## Common commands

```bash
acli jira auth status                                    # Verify auth
acli jira workitem view MAC-12345                        # View issue details
acli jira workitem view MAC-12345 --json                 # Full JSON output
acli jira workitem view MAC-12345 --fields "*all"        # All fields
acli jira workitem comment list --key MAC-12345          # List comments
acli jira workitem comment list --key MAC-12345 --limit 5  # Recent comments
acli jira workitem transition --key MAC-12345 --status "In Progress" --yes  # Transition status
acli jira workitem assign --key MAC-12345 --assignee "user@example.com" --yes  # Assign
acli jira workitem assign --key MAC-12345 --assignee "@me" --yes  # Self-assign
acli jira workitem comment create --key MAC-12345 --body "text"  # Add comment
```

## Searching (JQL-based)

All list/search operations use `acli jira workitem search` with `--jql`:

```bash
acli jira workitem search --jql "project = MAC" --limit 20                              # List issues
acli jira workitem search --jql "project = MAC AND status = 'In Progress'" --limit 20   # By status
acli jira workitem search --jql "project = MAC AND assignee = 'ashton.eby@machinify.com'" --limit 20  # By assignee
acli jira workitem search --jql "project = MAC AND type = Bug" --limit 20               # By type
acli jira workitem search --jql "project = MAC AND priority = High" --limit 20          # By priority
acli jira workitem search --jql "project = MAC AND created >= -7d" --limit 20           # Created recently
acli jira workitem search --jql "project = MAC AND updated >= startOfDay()" --limit 20  # Updated today
acli jira workitem search --jql "project = MAC AND labels = backend" --limit 20         # By label
```

Combine filters in JQL: `status IN ("New", "In Progress") AND type = Bug`.

## Creating / editing

```bash
acli jira workitem create --project MAC --type Bug --summary "Title" --description "Details"
acli jira workitem edit --key MAC-12345 --summary "New title"
acli jira workitem edit --key MAC-12345 --description "Updated description"
```

## Useful flags

| Flag | Purpose |
|------|---------|
| `--json` | Full JSON output (replaces `--raw`) |
| `--csv` | CSV output (search only) |
| `--limit N` | Max results for search |
| `--fields "key,summary,..."` | Select fields for view/search |
| `--yes` / `-y` | Skip confirmation prompts |
| `--web` / `-w` | Open in browser |

## Sprints

Sprint commands require a board or sprint ID — no simple `list all sprints`:

```bash
acli jira sprint view {SPRINT-ID}
acli jira sprint list-workitems {SPRINT-ID}
```
