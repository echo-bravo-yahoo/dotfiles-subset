---
name: reflect
description: Use when the user says "reflect", "session recap", "end of session", or asks for a summary of what was accomplished. Analyzes permissions, failures, learnings, and logs to daily notes.
---

# Session Reflection

Perform end-of-session retrospection to improve future Claude Code sessions.

## Instructions

Analyze the current conversation and produce structured output covering the sections below. Be thorough but concise. **Omit any section that has no relevant information for this session.**

---

## 1. Permission Analysis

Review tool calls that were blocked or prompted by cc-allow during this session.

### Steps:
1. Read the cc-allow reference at `~/.claude/docs/cc-allow.md`
2. Read existing cc-allow rules from `~/.config/cc-allow.toml` (global) and `.config/cc-allow.toml` (project, if it exists)
3. Identify all tool calls that were blocked (deny) or prompted (ask) by cc-allow during the session
4. For each blocked/prompted action, determine whether the current rule is appropriate or should be adjusted:
   - **Keep as deny**: Genuinely dangerous or irreversible
   - **Change to ask**: Safe enough with user confirmation (e.g., editing a specific config file)
   - **Change to allow**: Frequently used and clearly safe (e.g., a read-only command)
5. Suggest concrete TOML rule changes, using correct cc-allow syntax (see reference doc for pattern prefixes, specificity, etc.)

### Before editing cc-allow files:

Check for TOML validity issues that will break parsing:
- **Duplicate table headers**: Search the file for the `[section]` being added. A `[table]` can only appear once — adding a second `[edit.ask]` when one exists is a fatal parse error. Merge keys into the existing section instead.
- **`[table]` vs `[[array]]` mismatch**: If the file already uses `[[bash.allow.npm.run]]` (array of tables), never add `[bash.allow.npm.run]` (standard table) for the same path, or vice versa.
- **Duplicate keys in the same table**: e.g., two `paths =` lines under `[edit.ask]`. Merge values into the existing key's array.
- **Section splitting**: Inserting a new `[section]` between a table header and its keys silently reassigns those keys to the new section. Append new sections at the end of the relevant rule group or at EOF.

After editing, validate with:
```bash
cc-allow --fmt
# or for a specific file:
cc-allow --fmt --config <file>
```
If validation fails, fix the issue before finishing. Do not leave a broken config.

### Output Format:
```
### Suggested cc-allow Changes

**Global** (`~/.config/cc-allow.toml`):
- Add `[edit.ask]` for `path:$HOME/.zshenv` — needed for shell config edits
- Add `[[bash.allow.brew.install]]` — frequently used, low risk

**Project** (`.config/cc-allow.toml`):
- Add `[[bash.allow.npm.test]]` — test runner for this project
```

---

## 2. Failure Analysis

Identify commands/tools that failed and were retried.

### Categorize failures:
- **Missing dependencies**: Tool/package not installed
- **Incorrect parameters**: Wrong flags or arguments
- **Environment issues**: Path, version, config problems
- **Permission denied**: File or system access issues

### Output Format:
```
### Failures & Retries

| Command | Failure Type | Resolution |
|---------|--------------|------------|
| `npm test` | Missing dependency | Installed jest |
| `rg -l pattern` | Incorrect params | Added `--glob` flag |

### Suggested Remediation:
- Add to CLAUDE.md: "Run `npm install` before testing"
- Install: `brew install ripgrep`
```

---

## 3. CLAUDE.md Delta

Compare session learnings against existing project documentation.

### Steps:
1. Read `./CLAUDE.md` if it exists in the current working directory
2. Identify undocumented patterns discovered during this session:
   - Project conventions
   - File organization patterns
   - Build/test/lint commands
   - Required environment setup
   - Team preferences or coding standards

### Output Format:
```
### Suggested CLAUDE.md Updates

**New file needed**: No CLAUDE.md exists. Consider creating one.

**Additions for existing CLAUDE.md**:
- Add under "Build Commands": `npm run build:prod` for production builds
- Add convention: "Components use PascalCase, hooks use camelCase"
- Note: Tests require `DATABASE_URL` env var
```

---

## 4. Daily Note Update

Log session accomplishments to the daily note.

### Steps:
1. Determine today's date (YYYY-MM-DD format)
2. Read `~/notes/10-19 life/10 meta/10.01 daily/YYYY-MM-DD.md`
3. Determine placement:
   - **Work section** (`## Work`, before `### To-do today`): Git repos with work indicators, Jira tickets
   - **Notes section** (`## Notes`): Personal/non-work tasks
4. Gather context:
   - Git branch, recent commit hash, worktree path (if in git repo)
   - Jira ticket references from conversation
   - Existing tags used in the note (do not invent new tags)
5. Consolidate similar tasks into single bullets
6. **Repository hyperlinks**: The first mention of a repository name in a daily note entry should be a markdown link to the repo. Run `git remote get-url origin` to get the remote URL, convert SSH URLs (`git@github.com:user/repo.git`) to HTTPS (`https://github.com/user/repo`), and format as `[repo-name](url)`.

### Before editing:
- Show the proposed bullets to the user
- Wait for confirmation before modifying the file

### Output Format:
```
### Proposed Daily Note Entry

Section: ## Work

- Implemented user authentication flow for [myapp](https://github.com/user/myapp) (`feature/auth`, `abc123f`) #backend
- Fixed pagination bug in search results (`bugfix/search-page`, `def456a`) [[PROJ-123]]
```

Note: Repository name is hyperlinked on first mention only.

---

## 5. Taskwarrior Cleanup

Check for relevant tasks and mark them complete.

### Steps:
1. Run `task list` to see pending tasks
2. Identify tasks related to work done this session (match by description, project, or tags)
3. For each matching task, show the task and ask for confirmation before marking done
4. Mark confirmed tasks complete with `task <id> done`

### Output Format:
```
### Taskwarrior Updates

| ID | Description | Action |
|----|-------------|--------|
| 42 | Fix auth bug | Marked done |
| 57 | Update docs | Skipped (partial) |
```

---

## 6. Additional Insights

### External Resources
- List URLs and documentation referenced during the session
- Note if any should be added to CLAUDE.md or bookmarked

### Shell Alias Suggestions
If any long commands were run multiple times:
```
# Add to ~/.zshrc
alias tbd='npm run build:dev && npm run test'
```

### MCP Tool Patterns
Track MCP tools used (Atlassian, etc.) and suggest permission additions if frequently denied.

### Workarounds Used
Note any workarounds employed for missing functionality - potential CLAUDE.md guidance or feature requests.

### Dependencies Installed
List packages/tools installed during session for documentation.

### Hook Suggestions
If manual validations were repeated, suggest hooks:
```yaml
# .claude/settings.json
hooks:
  PreCommit:
    - command: npm run lint
```

---

## 7. Conversation Naming

Rename the conversation to reflect what was accomplished.

### Steps:
1. Summarize the primary accomplishment(s) in 1-8 words
2. Use lowercase with spaces (natural language)
3. Include project/repo name if session focused on one project
4. Prefer action-oriented names: "fix X", "add Y", "refactor Z"

### Examples:
- `towers single pass git blame`
- `fix auth token refresh`
- `add dark mode support`
- `olapui refactor api error handling`

### Action:
Copy the name to clipboard with `echo -n "NAME" | pbcopy` and tell the user to run `/rename` and paste.

---

## Execution Notes

- Analyze the *current conversation* only - no external state tracking
- Recommendations should be copy-pasteable
- Daily note edits are additive only
- Show proposed changes before applying any edits
- Use existing tags from notes; never invent new ones
