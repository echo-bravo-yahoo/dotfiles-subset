# Planning

## When to plan

Plan when any of these apply:

- The change spans 3+ files
- Multiple valid approaches exist and the tradeoffs are non-obvious
- The codebase area is unfamiliar — exploration is needed before implementation

Skip planning when the diff is describable in one sentence (typo fix, rename, add a log line).

## Research broadly before proposing a plan

Before committing to an approach, survey what already exists:

- **Web search** for prior art, known pitfalls, and idiomatic solutions
- **Read open-source libraries** that solve the same or adjacent problem — check their API surface, implementation strategy, and tradeoffs
- **Use `--help` and `man` pages** for CLI tools involved in the change; don't assume flag behavior from memory
- **Check project dependencies** — a solution may already be available through an installed library

The goal is to avoid reinventing something that's already solved and to surface constraints early. Narrow the search once a direction is clear, but start wide.

## Plan content guidelines

- **Audience-appropriate detail**: match the plan's granularity to the task complexity. A 3-file refactor needs less detail than an architectural migration.
- **No implementation in the plan**: plans describe _what_ and _why_, not exact code. Pseudocode is acceptable for complex logic.
- **Reference existing patterns**: when the codebase has a convention, name it and point to an example file rather than describing it from scratch.
- **Scope boundaries**: explicitly state what is _not_ included if the task could reasonably be interpreted more broadly.
- **Verification strategy**: include how to confirm the change works (tests, commands, visual checks).

## Anti-patterns

| Anti-pattern | Problem | Fix |
|---|---|---|
| Planning trivial tasks | Wastes tokens and delays execution | Just do it directly |
| Massive monolithic plans | Hard to review; user skims and misses issues | Break into phases or separate PRs |
| Planning without exploring | Plan is based on assumptions, not actual code | Explore the relevant code first |
| Over-specifying implementation | Plan becomes brittle; any deviation feels like failure | Describe intent, not exact lines of code |
| Ignoring plan during implementation | Plan was wasted effort; result diverges from expectations | Reference the plan; note deviations explicitly |
| Re-planning after every correction | Slows momentum on small adjustments | Only re-plan if scope or approach changes fundamentally |
