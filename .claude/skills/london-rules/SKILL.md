---
name: london-rules
description: "Generate a project development history report with a mermaid timeline, anonymized narrative, and raw data file. Use when asked to document how a feature was built, create a project timeline, or produce a development retrospective."
argument-hint: "<repo-path> [--tickets X] [--prs X] [--range YYYY-MM-DD..YYYY-MM-DD]"
---

# London Rules — Project History Report

Generate a three-artifact system documenting a feature's development history:
1. **Mermaid Gantt chart** — visual timeline of events and blockers
2. **Report** — anonymized, neutral prose explaining each chart event
3. **Data file** — raw lookup tables with real names, IDs, and re-fetchable evidence coordinates

---

## Phase 0: Intake

### Step 1: Write and open the intake template

Write this template to `/tmp/london-rules-intake.md` and open it in the user's editor (use the `open` skill):

```markdown
# London Rules — Intake

## Starting point
<!-- The best starting point is an OKR number (e.g., "KR 4.1") or epic ticket (e.g., "MAC-26889").
     Otherwise, provide a feature name, ticket number, or PR number. -->
Starting point:

## Date range (approximate)
From:
To:

## Known artifacts
<!-- Any of these you already know. Leave blank if unknown — the skill will discover them. -->
JIRA tickets:
GitHub PRs:
Git branches:
Slack channels:
Notion pages:

## People involved
<!-- List everyone involved. The skill will propose role labels. -->
-
-

## Audience & purpose
<!-- Who will read this report? What should it demonstrate? -->
Audience:
Purpose:

## Repo path
<!-- Absolute path to the git repository -->
Repo:
```

Wait for the user to save the file, then read it back.

### Step 2: Propose name-to-role mapping

From the people listed, propose a mapping table:

| Name | Role label |
|------|-----------|
| Alice | the primary developer |
| Bob | the reviewer |
| Carol | the API developer |
| ... | ... |

Default role labels: primary developer, additional developer, designer, API developer, engineering management, architect, product, QA, infrastructure developer.

Rules:
- Multiple people in the same role become one label (e.g., two backend devs both become "the API developer")
- Names stay in the data file; role labels go in the report and chart

Ask the user to confirm or edit before proceeding.

### Step 3: Verify tool access

Run these checks **in parallel**:

| Tool | Check | Required? |
|------|-------|-----------|
| Git CLI | `git log --oneline -1` in repo | **Required** — will not proceed without |
| GitHub CLI (`gh`) | `gh pr view <known-PR>` | **Required** — will not proceed without |
| Slack MCP | `slack_search_users` for a known user | Strongly recommended |
| JIRA CLI or API | `jira issue view <ticket>` or curl REST API | Strongly recommended |
| Mermaid npm package | `node -e "require('mermaid')"` | Strongly recommended |
| Notion MCP | `notion-search` for a known page | Strongly recommended |

**Progressive fallback with confirmation.** If any non-required tool fails:
- Report which tools are available and which are not
- Explain what data will be missing (see Fallback Behavior below)
- **Ask the user to confirm** before proceeding with reduced data
- Do NOT silently proceed — the user may prefer to fix access first

#### Fallback behavior

- **No Slack:** Report will lack "why" context for decisions and blockers. Timeline events will be dated but not explained in depth.
- **No JIRA CLI (`jira` not found):** Offer to install: `brew install jira-cli` (macOS) or `go install github.com/ankitpokhrel/jira-cli/cmd/jira@latest`. Falls back to `curl` against the Atlassian REST API if user prefers not to install.
- **No JIRA credentials (CLI installed but auth fails):** Run `jira init` to configure, or ask user for a fresh API token. Tokens expire. The REST API uses Basic auth: `email:token` base64-encoded. New search endpoint: POST `/rest/api/3/search/jql` (old GET `/rest/api/3/search` is removed).
- **No mermaid validation (`mermaid` not found):** Offer to install: `npm install mermaid@<version>` in a temp directory (e.g., `/tmp/mermaid-test/`). Ask the user what version their renderer uses. If unknown, default to latest but warn about version-specific syntax.
- **No Notion:** Report will lack OKR status snapshots and design docs. User can paste content manually as a workaround.
- **No calendar data:** Flag this gap so the user knows to volunteer meeting dates — meetings are often scope-change inflection points.

---

## Phase 1: Research

**Goal:** Build the raw evidence base. Write findings to the data file as you go.

### Source priority (most reliable first)

1. **Git history** — Use `--format='%aI'` for author dates, not committer dates.

   **Rebase warning:** Rebases, cherry-picks, and interactive rebases overwrite committer dates and can scramble author dates. If the branch has been rebased, commit dates are unreliable. Look for pre-rebase branches (backup branches, `reflog`, or branches named `-original`, `-backup`, `-wip`). PR open/close/merge dates from GitHub are immutable and more trustworthy than any git date on a rebased branch.

2. **GitHub PRs** — PR open/close/merge dates, review comments, review rounds, diff stats. Use `gh pr view` and `gh api`. These dates are **authoritative** — they cannot be rewritten.

3. **JIRA** — Ticket timeline (created, status changes, comments). Epic → child relationships via `"Epic Link" = <key>`. Estimation data in `timeoriginalestimate` field or description text.

4. **Slack** — DMs and channels for context. Search with `from:<@ID>` + keywords + date ranges.

   **DM sensitivity rules:**
   - The skill runs as the authenticated Slack user and can only read DMs that user is part of. The report is inherently from one person's vantage point.
   - **Never quote DMs verbatim in the report.** Paraphrase into neutral third-person.
   - **DM quotes are acceptable in the data file** but flag them with a `[DM]` prefix so the user can review before sharing.
   - **Acknowledge the perspective bias** in the report introduction: "This report is based on artifacts and communications visible to [role]. Other participants may have additional context."
   - When DM content could be read as blaming someone, reframe around the *process gap* not the *person*: "The spec was delivered 5 days after the requested date" not "The developer was 5 days late."

5. **Notion** — OKR dashboards, design docs, proposals. Often has weekly status snapshots with color-coded health indicators.

6. **Calendar** — User can paste meeting dates. Meetings often mark inflection points (scope changes, blocker discovery, architecture decisions).

### Date authority hierarchy

When dates conflict between sources, trust in this order:
1. GitHub PR dates (immutable)
2. Git author dates on non-rebased branches
3. JIRA ticket creation/comment timestamps
4. Slack message timestamps
5. Self-reported dates in JIRA comments or Slack messages ("I finished this yesterday")
6. Git dates on rebased branches (least trustworthy)

---

## Phase 2: Timeline Construction

**Goal:** Build the mermaid Gantt chart.

### Steps

1. Identify major events: start of work, handoffs, blockers, deliveries, review rounds, merge, post-merge.
2. Categorize:
   - Active work → default (blue bars)
   - Blockers → `:crit` (red bars)
   - State transitions → `:milestone` (diamonds)
3. Group into sections matching the development flow (design, build, integration, review, post-merge).
4. Validate after every edit (see Mermaid Debugging below).
5. Iterate with the user. The chart is the skeleton — get it right before writing prose.

### Chart rules

- **Events map 1:1 to bars/milestones.** Every bar gets a `###` section in the report.
- **Describe what, not how.** "Scaffold for 2 of 3 pages" not "builds AG Grid, SQL editor." Focus on deliverables.
- **No names in the chart.** Use role descriptions if attribution is needed.
- **No ticket/PR numbers in the chart.** Those go in the data file.
- **Prefer deliverable-backed dates.** PR open/close dates and git author dates over JIRA reports or Slack messages.
- **"Code complete" claims require scrutiny.** If requirements grew after a "done" report, note both dates.

### Mermaid debugging

When charts fail to render:
1. Check for **blank lines between sections** — some mermaid versions reject them.
2. Check for **`#` characters in labels** — breaks parsing in most versions.
3. **Compare mermaid versions** — syntax accepted by v11 may fail on v10. Always test with the user's renderer version.
4. **Strip to minimal reproducer** — remove all events, add them back one at a time to isolate the failure.
5. **Use `mermaid.parse()` programmatically** via JSDOM rather than `mmdc` CLI for faster iteration:
   ```javascript
   const { JSDOM } = require('jsdom');
   const dom = new JSDOM('<!DOCTYPE html><html><body></body></html>', { pretendToBeVisual: true });
   global.window = dom.window; global.document = dom.window.document;
   global.navigator = dom.window.navigator; global.DOMParser = dom.window.DOMParser;
   const mermaid = require('mermaid');
   mermaid.default.parse(require('fs').readFileSync('/tmp/chart.mmd','utf8'))
     .then(() => console.log('VALID'))
     .catch(e => console.log('ERROR:', e.message));
   ```

---

## Phase 3: Report Writing

**Goal:** Write the anonymized prose.

### Structure

```markdown
# <Feature Name>: Development Timeline

## Introduction
<!-- 2-3 sentences: what the feature is, total timeline, current state -->
<!-- Scope note: what this covers and doesn't cover -->
<!-- Perspective note: "based on artifacts visible to [role]" -->

## Timeline
<mermaid chart>

## <Section Name>
### <Event Name> (date, duration)
<!-- 2-5 sentences per event -->
```

One `##` section per chart section. One `###` per chart event.

### Report rules

- **Anonymized.** Use role labels from the confirmed mapping. No real names anywhere.
- **Neutral, non-accusatory tone.** "The spec was delivered on Jan 27" not "The developer was late with the spec."
- **No inline source citations.** The data file holds all sourcing; the report is clean prose.
- **No JIRA/PR numbers** except in PR Review sections where PRs are the subject.
- **2-5 sentences per event.** What happened, why it took the time it did, what blocked progress.
- **Red bars must explain what made them blockers.** Milestones must explain what changed.
- **Avoid red herrings.** If a tangent didn't meaningfully affect the timeline, exclude it.
- **Draw content from the data file**, not from re-searching sources.

---

## Phase 4: Data File

**Goal:** Create the raw reference file with re-fetchable evidence.

### Structure

```markdown
# <Feature Name> — Timeline Data

## Event Rationale
<!-- Per-event explanations with source citations -->

## Lookup Tables
### People
### Slack Channels & DMs
### JIRA Tickets
### GitHub PRs
### Git Branches
### Notion Pages

## Key Evidence
<!-- Pivotal quotes with channel ID + message_ts for re-fetching -->

## Estimation Data
<!-- If estimation sessions were found -->

## Phase Summaries
<!-- Narrative phase → mermaid event mapping -->
```

### Data file rules

- **Real names, real IDs.** Slack user IDs, JIRA keys, PR numbers, channel IDs, message timestamps.
- **Can be unflattering but accurate.** "Premature 'done' claim" is fine here. Direct quotes acceptable.
- **DM quotes prefixed with `[DM]`** so the user can review before sharing.
- **Re-fetchable coordinates.** Every quote needs: channel ID + message_ts for Slack, ticket key + comment date for JIRA, PR number for GitHub.
- **Lookup tables over prose.** Tables for people, channels, tickets, PRs, branches, Notion pages.
- **Phase-to-mermaid mapping.** Connect narrative phases to specific chart events.

---

## Phase 5: Retrospective

After the report and data file are complete, append a **blame-free retrospective** section to the report. Derived from timeline data, not new research.

### Structure

```markdown
## Retrospective

### What went well
<!-- Periods of productive work, successful handoffs, blockers resolved quickly -->

### What didn't go well
<!-- Recurring patterns: blocked on dependencies, scope discovered late,
     review cycles extended by external churn -->

### What to change
<!-- Process recommendations citing specific timeline events -->
```

### Rules

- **No names.** Same role labels as the report.
- **Pattern-focused, not incident-focused.** "API specs were requested 4 weeks before delivery" not "The API developer was slow." If a pattern happened once, it's an incident — note it but don't generalize.
- **Recommendations must be actionable.** "Agree on API contract before UI dev begins" not "Communication could be better."
- **Cite timeline events.** Each item references the chart event(s) that motivate it: "See: *Blocked on API spec (Jan 12, 16d)* and *New API gaps found (Feb 19, 9d)*."

---

## Phase 6: Review

Verify completeness:
1. Every chart event has a `###` section in the report.
2. No personal names appear in the report or chart.
3. Dates match between chart and prose.
4. Mermaid chart validates at the correct version.
5. Data file has re-fetch coordinates for every assertion.
6. DM-sourced quotes are flagged with `[DM]` in the data file.
7. Retrospective cites specific timeline events.

---

## Output Files

| File | Content | Naming |
|------|---------|--------|
| Report | Mermaid chart + anonymized prose + retrospective | `<feature-name>-history.md` |
| Data file | Lookup tables, evidence, re-fetch coordinates | `<feature-name>-data.md` |

Both files are written to the user-specified directory (default: `~/`).
