---
name: audit
description: "Audit project Claude documentation for build, test, and run coverage. Use when asked to audit, check, or review a project's CLAUDE.md completeness."
---

# Project Documentation Audit

Read all Claude documentation for the current project and report coverage. Report only — do not create, scaffold, or modify any files.

## What to Read

1. `CLAUDE.md` in the project root
2. All files under `.claude/` (settings, docs, scripts, etc.)
3. If an argument path was provided, use it as the project root

Read every file found. Build/test/run info may appear in any of these locations.

## What to Check

For each area, determine: **documented**, **partially documented**, or **missing**.

### Build
- Command to build the project
- Output location (e.g., `dist/`, `target/`, `build/`)
- Worktree differences (if applicable): does building in a worktree differ from the repo root?

### Test
- Command to run all tests
- How to run a single file or scope tests
- Special flags or environment requirements
- Worktree differences (if applicable)

### Run
- Command to run the project, binary, or dev server
- For CLIs: distinction between installed binary and local build output
- For servers/apps: dev server start command
- Worktree differences (if applicable)

## Output Format

```
## Project Documentation Audit

**Root:** <project root path>
**Files read:** <list of files examined>

### Build
- Status: <Documented | Partially documented | Missing>
- Present: <what's covered>
- Missing: <what's absent>

### Test
- Status: <Documented | Partially documented | Missing>
- Present: <what's covered>
- Missing: <what's absent>

### Run
- Status: <Documented | Partially documented | Missing>
- Present: <what's covered>
- Missing: <what's absent>

### Worktree Coverage
- Status: <Documented | Partially documented | Missing | N/A>
- Notes: <brief explanation>

### Summary
<One-sentence overall assessment>
```
