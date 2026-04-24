# Markdown Traversal with mdq

## Rule

**Before using Read on any `.md` file, check its size first:**

```bash
wc -l < file.md
```

If the file exceeds 500 lines, **do NOT use Read**. Use the heading-first strategy below instead. Read loads the entire file into context, wasting thousands of tokens when only one section is needed.

## Setup

Verify `mdq` is available before use:

```bash
command -v mdq || brew install mdq
```

If Homebrew is unavailable: `cargo install --git https://github.com/yshavit/mdq`

## Strategy: Heading-First Traversal

Two tools, used in sequence — Grep to scan, mdq to extract.

**Step 1 — Scan headings** with the Grep tool:

```
Grep(pattern: "^#{1,6} ", path: "file.md")
```

This returns all heading lines — typically 50-130 lines regardless of file size. For a 2,359-line file, this is a 95% reduction.

**Step 2 — Identify:** Read the heading list and pick the section(s) relevant to the task.

**Step 3 — Extract the target section** with mdq via Bash:

```bash
mdq '#{2} "Section Name"' < file.md
```

Returns the heading and all content under it (including sub-headings), stopping at the next sibling heading. Heading level syntax: `#{2}` for H2, `#{3}` for H3, `#` for any level.

**Step 4 — Narrow before reading** (when the target section has many sub-headings):

If the heading scan shows the relevant section has many sub-headings, decide whether to read the full section (step 3) or go directly to a sub-section:

```bash
mdq '#{2} "Parent" | #{3} "Child"' < file.md
```

The pipe (`|`) chains selectors — read only the matching sub-section, not the entire parent. If most sub-headings look relevant, use step 3 (full section). If only one or two are relevant, use step 4. Bias for correctness — reading too much is better than missing context.

## When NOT to Use

- File is small (<500 lines) — use Read directly
- Need the entire file (reviewing a config, auditing completeness)
- File is not markdown

## Selector Syntax

**CRITICAL:** `##` is NOT valid mdq syntax. Use `#{2}` for H2, `#{3}` for H3, etc.

| Goal | Selector |
|------|----------|
| Any heading matching title | `# "Title"` |
| Heading at exactly level N | `#{N} "Title"` |
| Headings at levels 2-4 | `#{2,4} *` |
| Title match (case-insensitive) | `# keyword` |
| Title match (case-sensitive) | `# "Exact Title"` |
| All list items in a section | `#{2} "Section" \| - *` |
| Code blocks in a section | `` #{2} "Section" \| ``` * `` |
| Chain / drill into sub-section | `#{2} "Parent" \| #{3} "Child"` |

### Output Modes

| Flag | Effect |
|------|--------|
| *(default)* | Markdown with formatting preserved |
| `-o json` | Structured JSON (pipe to `jq`) |
| `-o plain` | Plain text, markdown syntax stripped (includes full content, not just headings) |

### Link Extraction

mdq can extract markdown links with structured output:

```bash
mdq '[]()' -o json < file.md | jq '.items[].link | {display, url}'
```

Useful for index files that use `[name](path.md)` link syntax.

## Multi-File Scanning

When searching across multiple markdown files for which one covers a topic:

```bash
for f in docs/*.md; do
  echo "=== $(basename "$f") ==="
  mdq '#{2} *' -o json < "$f" | jq -r '.items[].section.title'
done
```

This dumps the H2 section titles of every file — enough to identify which file to drill into.

## Context Cost Comparison

| Approach | Steps | Context consumed |
|----------|-------|-----------------|
| `Read` full file | 1 tool call | Entire file (e.g., 2,359 lines) |
| Grep heading scan | 1 tool call | ~128 heading lines |
| Grep scan + mdq extract | 1 tool + 1 Bash | Headings + target section only |

For a 2,359-line file where the answer is in a 40-line section: ~170 lines loaded instead of ~2,359.
