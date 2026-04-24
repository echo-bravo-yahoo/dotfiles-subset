# CLAUDE.md Maintenance

## Docs coverage rule

Every file in `~/.claude/docs/**` must be referenced from `~/.claude/CLAUDE.md` with a trigger condition describing _when_ to read it. After adding a new docs file, add a corresponding reference to CLAUDE.md before finishing the task.

To verify coverage:

```bash
# List docs files not mentioned in CLAUDE.md
for f in ~/.claude/docs/*.md; do
  name=$(basename "$f")
  grep -q "$name" ~/.claude/CLAUDE.md || echo "Missing: $name"
done
```

## Inline vs. docs file

Keep short, always-relevant rules inline in CLAUDE.md. Move detailed reference material — syntax guides, multi-step procedures, tables of options — to a separate docs file.

Rule of thumb: if an inline section exceeds ~10 lines of detail, extract the detail into `~/.claude/docs/` and replace it with a summary + pointer.

## Trigger conditions

Each docs reference must clearly state _when_ to read the file. Good triggers are specific and action-oriented:

- "When working in Python" — language-specific tooling
- "When modifying cc-allow TOML rules" — tool-specific config
- "When adding or reorganizing docs files" — maintenance tasks

Avoid vague triggers like "see for more info" or "for reference."

## Section conventions

- Use `##` headings in CLAUDE.md. Keep each section focused on one topic.
- Group related docs references together (e.g., all language tooling docs in one "Language & Tooling Docs" section).
- Follow existing patterns — short intro line, then a "See `~/.claude/docs/...`" pointer.

## Audience

All instructions in CLAUDE.md and docs files are directives for Claude to follow, not guidance for the human user. When incorporating information from web sources (blog posts, tutorials, documentation), reframe it as Claude-actionable rules. Web content about Claude Code is almost always addressed to the human operator and must be adapted.

Examples of content that needs reframing:
- "Press Ctrl+G to open the plan in your editor" — this is a human action; omit or describe as a capability the user has
- "Open the plan file and add inline notes" — human workflow; instead describe what Claude should produce or expect as input
- "Use Shift+Tab twice to enter plan mode" — UI instruction for the human; not relevant to Claude's behavior

Only include instructions that Claude can act on: tool usage, output format, research strategy, code style, decision-making heuristics.

## Avoiding duplication

If detailed content lives in a docs file, CLAUDE.md should contain only a brief summary and a pointer. Don't maintain the same detailed instructions in both places — that creates drift.

When the same content exists inline and in a docs file (e.g., testing, tmux), the docs file is the source of truth. The inline version is a convenience summary.

## Global vs. project CLAUDE.md

| File | Scope | Purpose |
|---|---|---|
| `~/.claude/CLAUDE.md` | User-wide | Personal defaults, tooling preferences, workflow rules |
| `.claude/CLAUDE.md` | Project | Project-specific instructions (committed to VCS) |

Don't put project-specific rules in the global file. Don't put personal preferences in project files.
