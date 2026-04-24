---
name: amazon
description: "Find reasonable product candidates on Amazon for a shopping query. Returns a ranked shortlist with prices, ratings, justifications, and red flags."
argument-hint: "<what you want to buy>"
---

# Amazon Product Finder

Turn a shopping query into an opinionated shortlist. Scout the category, ask the user to disambiguate axes, run scoped searches, filter for credibility, corroborate against Reddit/Wirecutter, and deliver 3–5 ranked candidates with red flags. The goal: save the slow part (filtering noise) and hand the human a clean final choice.

## Inputs

**Argument**: natural-language query, optionally with flags.

Flags (also invocable via natural-language phrasing):

| Flag | Natural language | Effect |
|------|------------------|--------|
| `--n=N` | "top N", "show me N" | Results count (default 5) |
| `--no-ask` | "just search", "don't ask me" | Skip clarifying questions |
| `--no-external` | "amazon only", "skip reddit" | Skip Reddit/Wirecutter corroboration |
| `--format=table` | "comparison table" | Table output |
| `--format=json` | "as JSON" | JSON output |
| `--save` | "save this to notes" | Write `~/notes/10-19 life/19 purchase-research/<slug>.md` |
| `--open` | "open the top 3" | Invoke `/open` on top URLs |
| `--task` | "add a task" | `task add project:personal "Buy <query>" link:<top-pick-url>` |
| `--tld=X` | "search amazon.co.uk" | Use `amazon.<tld>` |

## Workflow

### 1. Parse the query

1. Strip recognized flags from the argument; remainder is the query.
2. Extract constraints from the query via natural-language reasoning:
   - Price caps (`max_price`, `min_price`)
   - Features (e.g. `waterproof`, `USB-C`)
   - Size/color preferences
   - Brand names mentioned
3. Detect specificity. If the query already contains brand + model (e.g. "Sony WH-1000XM5") or brand + category + a tight price cap, flag it as **tight** — skip step 3 below.

### 2. Scout the category

One exploratory Amazon search to learn what axes products in this category differ on. Results here are **not shown to the user**.

```
WebFetch https://www.amazon.com/s?k=<urlencoded-query>
```

If the fetch returns a captcha/block page or zero product hits, jump to **Fallbacks** (bottom of this file).

From the raw results, identify:
- Recurring feature axes (e.g. for keyboards: switch type, layout, connectivity, RGB, price tier)
- Observed price range
- Whether the category is brand-concentrated or fragmented

### 3. Disambiguate

Skip this step if Phase 1 flagged the query as **tight**, or if `--no-ask` was passed.

Compose up to 4 clarifying questions from the axes identified in step 2. Use `AskUserQuestion` with multiple-choice options drawn from the top-3 values observed during scouting, plus a "no preference" option for each.

Always include a **Budget** question if no price cap was in the original query.

Example (for "running shoes"):
1. **Distance**: Daily trainer / Long distance / Speed work / No preference
2. **Surface**: Road / Trail / Treadmill / No preference
3. **Cushioning**: Max / Balanced / Minimal / No preference
4. **Budget**: < $80 / $80–$150 / $150+ / No cap

Fold answers back into `constraints`.

### 4. Scoped search

Generate 2–4 parallel Amazon search strings that cover the tightened constraint space. Fetch each, parse into `ProductRecord`s (schema below), dedup by ASIN across searches.

```
WebFetch https://www.amazon.com/s?k=<search-string-N>
```

Each variant is its own SKU — don't fold sizes/colors into a single entry.

**ProductRecord fields**:
- `asin`, `title`, `url` (affiliate-stripped — see **Fallbacks > URL hygiene**)
- `price` (current only; `null` if unknown), `currency` (default USD)
- `rating`, `review_count`
- `shipping_eta`, `bought_past_month`
- `sponsored: boolean`
- `astroturf_flags: string[]`
- `external_mentions: string[]`
- `score: number`

Unknown fields are `null` — never fabricated.

### 5. Enrich & corroborate

Skip this step if `--no-external` was passed or if the timebox (see **Fallbacks > Timebox**) is exhausted.

For the top ~8 ranked candidates so far:
1. `WebFetch` the product detail page to fill `shipping_eta` and `bought_past_month` if missing.
2. In parallel:
   - `WebSearch "best <query> reddit"` → extract ASINs or product names
   - `WebSearch "<query> wirecutter OR rtings OR nytimes"` → pull editorial picks
3. For each candidate whose ASIN or fuzzy-matched title appears in external sources, add a source string to `external_mentions` and boost `score` (see **Heuristics**).

Optional: if a top pick's ASIN is compelling, fetch `https://camelcamelcamel.com/product/<asin>` and add a one-liner about current price vs. 90-day median.

### 6. Rank

See **Heuristics** for the full scoring rules. Starting score 100; apply additive adjustments. Sort descending. Take top N (default 5; honor `--n=N` or "show me N" natural-language).

### 7. Render

Choose the template based on flags or natural-language request:
- **Default**: ranked list (see **Templates > Ranked list**)
- **`--format=table`**: comparison matrix (see **Templates > Table**)
- **`--format=json`**: JSON array of `ProductRecord`s

Strip affiliate `?tag=` params from every URL before rendering (see **Fallbacks > URL hygiene**).

### 8. Side effects

In order, based on flags / natural-language:
- **`--save`**: write `~/notes/10-19 life/19 purchase-research/<slug>.md` (see **Templates > Saved note**)
- **`--open`**: invoke `/open` on the top 3 URLs
- **`--task`**: `task add project:personal "Buy <query>" link:<top-pick-url>`
- If the user picks a single finalist during a follow-up exchange, `pbcopy` the URL and note `(copied)`.

## Heuristics

All thresholds are defaults; adjust in-session if the user asks.

### Credibility floor (hard gate)

- Passes: `rating >= 4.0 AND review_count >= 500`
- Candidates below the floor go into a "low-credibility" bucket, only shown if fewer than 5 passed.

### Astroturf demotion (`-20` each, max `-50`)

- `review_count < 100 AND rating >= 4.9` → flag `low-review-high-star`
- Generic / unknown brand-looking title (opens with all-caps acronym, no-vowel jumble) → flag `generic-brand`

### Sponsored marker (`-10`)

Sponsored listings are kept but annotated with `[sponsored]` in output.

### External corroboration boost (`+15` each, max `+30`)

- ASIN or fuzzy-matched title in a Reddit megathread/top comment → `+15`
- ASIN or fuzzy-matched title in a Wirecutter / RTINGS / NYT review → `+15`

### No variant folding

Variants (size/color SKUs) rank independently. If two top-ranked results are variants of the same product, both appear.

## Templates

### Ranked list (default)

```markdown
## Top picks for "<query>"

_<N candidates scanned · <M> passed credibility floor · expanded queries: "Q1", "Q2", ...>_

### 1. [<title>](<clean-url>)
**$<price>** · ★<rating> (<review_count> reviews) · <shipping_eta>
<1-line justification>
<red flags, if any>

### 2. [<title>](<clean-url>)
...
```

End the output with a one-line summary of which queries were run and which axes the user disambiguated.

### Table

```markdown
| # | Product | Price | Rating | Reviews | Notes |
|---|---------|-------|--------|---------|-------|
| 1 | [Title](url) | $X | ★4.6 | 12,431 | Wirecutter top pick |
| 2 | [Title](url) | $Y | ★4.4 | 8,212 | low-review-high-star |
```

### JSON

Array of `ProductRecord`s, pretty-printed.

### Saved note

Write to `~/notes/10-19 life/19 purchase-research/<slug>.md`. Filename convention matches what's already there: plain topic, no date prefix (e.g. `backpack.md`, `monitor arms.md`).

- Slug: query lowercased, spaces preserved (e.g. `cast iron skillet.md`, `mechanical keyboard.md`).
- If the file already exists: **append** a new section with a `## <YYYY-MM-DD>` heading rather than overwriting. The file is an evolving research log.
- New-file body opens with minimal frontmatter + today's ranked-list section:

```markdown
---
tags:
  - purchase-research
  - amazon
  - claude
---

## <YYYY-MM-DD>

<default ranked-list output>
```

## Fallbacks

### Anti-bot

Triggered when a WebFetch returns a captcha, a blocked page, or zero product hits on a query that should clearly return hits.

1. `WebSearch "site:amazon.com <query>"` → extract Amazon URLs → `WebFetch` each detail page directly (detail pages are less aggressively blocked than search pages).
2. If still failing, `WebSearch "<query> review"` → Reddit / Wirecutter / RTINGS roundups → extract ASINs → `WebFetch` product pages.
3. If all fail: return a partial-result message telling the user Amazon is blocking and offering to retry with `--no-external` or a different query.

No browser fallback.

### Timebox

Hard cap of ~12 web calls per invocation: 1 exploratory + 4 scoped searches + 5 detail pages + 2 external searches. Count them and short-circuit enrichment once the cap is reached.

### URL hygiene

Strip the following from every URL before presenting:
- `?tag=...` and `&tag=...` affiliate parameters
- `ref=...` tracking params
- `qid=...`, `sr=...`, `th=...`, `psc=...` search-context params

Canonicalize to `https://www.amazon.com/dp/<ASIN>`. Never fabricate prices or ratings if parsing fails — mark the field `unknown`.

### Session dedup

Track ASINs shown earlier in the same conversation. On follow-up queries like "show me more" or "other options", explicitly exclude previously-shown ASINs from the rendered output. No cross-session memory.

### Error matrix

| Condition | Behavior |
|-----------|----------|
| Amazon blocks on search | Anti-bot fallback |
| Amazon blocks on detail page | Skip enrichment for that candidate; keep search data |
| WebSearch returns nothing useful | Return what Amazon data we have; note external-signal failure |
| Query too vague (scouting finds no axes) | Ask a single "what's the primary use case?" question |
| Zero candidates pass credibility floor | Show "low-credibility bucket" with a warning banner |
| Timebox exhausted mid-pipeline | Return partial results with a note |
| `AskUserQuestion` unavailable | Skip step 3 silently |
| Affiliate-param strip fails | Show the raw URL with a warning |
