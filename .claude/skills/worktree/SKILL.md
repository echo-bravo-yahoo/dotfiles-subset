---
name: worktree
description: Manage git worktrees for isolated development
argument-hint: "new <branch-name> | list | cleanup"
---

# Worktree Management

Manages git worktrees with context tracking for isolated development. Each worktree gets a `.claude-context.toml` file that tracks the associated Jira ticket, PR, conversation, and description.

## Context

```
! ls -d .worktrees 2>/dev/null || echo "No worktrees directory"
! git worktree list 2>/dev/null | head -5
```

## Commands

### `new <branch-name> [options]`

Create a new worktree with an isolated branch.

**Options:**
- `--base <ref>` - Base ref for the branch (default: `origin/main`)
- `--jira <TICKET>` - Jira ticket ID to associate
- `--conversation <id>` - Claude conversation ID to track
- `--description <text>` - Brief description of the work

**Steps:**

1. Run the worktree script:
   ```bash
   .claude/scripts/worktree.sh new "<branch-name>" --jira "<TICKET>" --conversation "<CONVERSATION_ID>" --description "<description>"
   ```

2. Change working directory to the new worktree path shown in the output

3. All subsequent work happens in that worktree context

**Example:**
```bash
.claude/scripts/worktree.sh new "fix/mac-12345" --jira "MAC-12345" --conversation "abc123" --description "Fix button alignment in dashboard header"
```

### `list`

List all worktrees with their context information.

```bash
.claude/scripts/worktree.sh list
```

Displays a table with:
- Worktree directory name
- Branch name
- Associated Jira ticket
- PR number (if created)
- Description

### `cleanup`

Remove worktrees whose PRs have been merged or closed.

**Dry-run (default):**
```bash
.claude/scripts/worktree.sh cleanup
```

**Actually delete:**
```bash
.claude/scripts/worktree.sh cleanup --force
```

The cleanup command:
1. Checks each worktree's context for a PR number
2. Queries GitHub for PR state (MERGED, CLOSED, or OPEN)
3. Removes worktrees and branches for merged/closed PRs

## Context File

Each worktree contains a `.claude-context.toml` file:

```toml
[context]
jira = "MAC-12345"
pr = "#123"
branch = "fix/mac-12345"
conversation = "abc123"
description = """
Fix the button alignment issue in the dashboard header
"""
```

### Updating Context

**When a PR is created**, update the context file:
```bash
# In the worktree directory
cat > .claude-context.toml << 'EOF'
[context]
jira = "MAC-12345"
pr = "#456"
branch = "fix/mac-12345"
conversation = "abc123"
description = """
Fix the button alignment issue in the dashboard header
"""
EOF
```

**When work scope changes**, update the description field to reflect the current state.

## Working with Dependencies

The worktree symlinks `node_modules` from the parent checkout for efficiency. However, if you need to modify `package.json` dependencies:

1. Remove the symlink:
   ```bash
   rm .worktrees/<name>/node_modules
   ```

2. Install dependencies in the worktree:
   ```bash
   cd .worktrees/<name>
   npm run npmi
   ```

3. Make your dependency changes

## Error Handling

| Scenario | Action |
|----------|--------|
| Branch already exists | Use a different branch name or delete the existing branch |
| Worktree directory exists | Remove the existing directory or use a different name |
| No context file | `-` shown in list output for missing fields |
| PR not found | Skipped during cleanup with a warning |
| node_modules missing | Warning shown; run `npm run npmi` in worktree if needed |
