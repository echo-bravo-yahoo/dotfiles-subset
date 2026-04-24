# Information Stores

A map of personal data systems: what belongs in each, how to query/update, and auth.

## Pinboard

**Purpose:** Reference bookmarks and workflow queues for web content.
**Auth:** Token `trial-in-error:XXXX` — store as `PINBOARD_API_TOKEN` in `~/.secrets.env` (also in 1Password "Dotfiles Secrets" → `pinboard_api_token`). Use env var, not hardcoded.
**API base:** `https://api.pinboard.in/v1/`
**What belongs:** Web pages worth returning to — articles, tools, repos, tutorials, recipes (link only), stores, game pages. NOT tasks, NOT items to buy (use Giftwhale for personal wishlist), NOT game wishlists (use ITAD).

**Key queues (underscore-prefixed tags):**
- `_return` — on all items; remove when "processed" (read, bought, played, etc.)
- `_readme` (17) — articles/pages to read
- `_feedme` (14) — RSS feeds to subscribe to
- `_music` (30) — music to listen to; purchaseable albums → Giftwhale, other → notes `25 music`
- `_buyme` (23) — gifts for other people (not self); stays in Pinboard as a purchase queue
- `_cookme` (2) — recipes to cook → notes `40.01 inbox`
- `_archived` (9) — archived items; keep
- `store` — artist shops and storefronts to return to when gift shopping
- `giftideas` — subset of `store`; artist/indie shop storefronts

**Query pattern:**
```bash
AUTH="auth_token=$PINBOARD_API_TOKEN"
# All items with a tag:
curl -sG "https://api.pinboard.in/v1/posts/all" \
  --data-urlencode "$AUTH" --data-urlencode "tag=TAGNAME" --data-urlencode "format=json" \
  | jq -r '.[] | "\(.href)\t\(.description)"'
# Tag counts:
curl -sG "https://api.pinboard.in/v1/tags/get" \
  --data-urlencode "$AUTH" --data-urlencode "format=json" \
  | jq -r 'to_entries | sort_by(-.value) | .[] | "\(.value)\t\(.key)"'
```

---

## Giftwhale

**Purpose:** The user's personal wishlist — items they want to receive as gifts. Shared at giftwhale.com for birthdays, Christmas, etc. so others can buy gifts for them.
**Auth:** Web only (no API). Log in at giftwhale.com.
**What belongs:** Specific purchaseable items the user wants for themselves. NOT gifts for others (those stay in Pinboard `_buyme`), NOT stores/shops (those stay in Pinboard `store`).
**Pinboard sources that feed here:** purchaseable `_music` items, specific items the user has decided they want.

---

## ITAD (IsThereAnyDeal)

**Purpose:** Game price-watch and waitlist. Preferred over Steam for tracking games to buy.
**What belongs:** Games to buy or watch for price drops. `_playme` Pinboard items with a purchase component → ITAD waitlist. Free/browser games → notes `31 play`.
**Web:** https://isthereanydeal.com/waitlist/

### Auth setup (one-time)

1. Log in at isthereanydeal.com
2. Register an app at https://isthereanydeal.com/apps/my/ — set redirect URI to `http://localhost:9876/callback`
3. Store the client ID in 1Password and in `~/.secrets.env` as `ITAD_CLIENT_ID`
4. Run `~/.aeby/scripts/itad-auth.sh` to complete the OAuth PKCE flow
5. Tokens are cached at `~/.aeby/itad-tokens.json`

### Auth script

`~/.aeby/scripts/itad-auth.sh` — scope: `wait_read wait_write`. On first run, performs OAuth 2.0 PKCE: opens browser → on WSL2, prompts for manual code paste → exchanges code for tokens → writes `~/.aeby/itad-tokens.json`. On subsequent runs, silently refreshes the cached token without browser involvement. Re-run whenever the token expires.

**WSL2 two-phase flow** (avoids code expiry from slow paste):
1. Run script normally → it saves the PKCE verifier to `/tmp/itad_pkce_state` and opens browser, then exits
2. After authorizing in browser, immediately run: `ITAD_AUTH_CODE="<code>" itad-auth.sh`

```bash
TOKEN=$(jq -r '.access_token' ~/.aeby/itad-tokens.json)
```

### API base

`https://api.isthereanydeal.com` — all authenticated requests: `-H "Authorization: Bearer $TOKEN"`

### Lookup: game ID from Steam app ID

```bash
TOKEN=$(jq -r '.access_token' ~/.aeby/itad-tokens.json)
curl -s "https://api.isthereanydeal.com/games/lookup/v1" \
  -H "Authorization: Bearer $TOKEN" \
  -G --data-urlencode "shop=steam" \
     --data-urlencode "game_id=270370" \
  | jq -r '.game.id'
```

### Lookup: game ID from title

```bash
curl -s "https://api.isthereanydeal.com/games/search/v1" \
  -H "Authorization: Bearer $TOKEN" \
  -G --data-urlencode "title=Chambara" \
  | jq -r '.[0].id'
```

### Add to waitlist

```bash
curl -s -X PUT "https://api.isthereanydeal.com/waitlist/games/v1" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '["<itad_game_id>"]'
# Multiple: '["id1", "id2"]'
```

### View waitlist

```bash
curl -s "https://api.isthereanydeal.com/waitlist/games/v1" \
  -H "Authorization: Bearer $TOKEN" \
  | jq -r '.[] | .title'
```

### Remove from waitlist

```bash
curl -s -X DELETE "https://api.isthereanydeal.com/waitlist/games/v1" \
  -H "Authorization: Bearer $TOKEN" \
  -G --data-urlencode "id=<itad_game_id>"
```

### Waitlist stats and notifications

```bash
# Price alerts / deal status
curl -s "https://api.isthereanydeal.com/waitlist/stats/v1" \
  -H "Authorization: Bearer $TOKEN" | jq .

# Notifications
curl -s "https://api.isthereanydeal.com/waitlist/notifications/v1" \
  -H "Authorization: Bearer $TOKEN" | jq .

# Sync waitlist with external service
curl -s -X PUT "https://api.isthereanydeal.com/user/sync/waitlist/v1" \
  -H "Authorization: Bearer $TOKEN"
```

### Workflow: Pinboard `_playme` → ITAD

1. Fetch `_playme` items: `curl … tag=_playme … format=json | jq`
2. For each item with a purchase component:
   - Has Steam URL: extract app ID → `games/lookup/v1?shop=steam&game_id={appid}`
   - No Steam URL: `games/search/v1?title={name}`
3. `PUT /waitlist/games/v1` with resolved ITAD IDs
4. Strip `_playme` tag from Pinboard (or delete if fully migrated)

---

## Steam Wishlist

**Purpose:** Steam-platform game tracking. Use ITAD where possible; Steam only for Steam-exclusive titles.
**Auth:** Steam API key `$STEAM_API_KEY` from `~/.secrets.env` (1Password "Dotfiles Secrets" → `steam_api_key`).
**Steam64 ID:** `76561197999053578`
**Write API:** None — Steam has no official endpoint for adding wishlist items. Use ITAD instead.

### Fetch wishlist

```bash
curl -s "https://api.steampowered.com/IWishlistService/GetWishlist/v1" \
  -G -d "key=$STEAM_API_KEY" -d "steamid=76561197999053578" \
  | jq -r '.response.items[].appid'
```

### Remove from wishlist (unofficial)

Requires `sessionid` + `steamLoginSecure` cookies from `store.steampowered.com` (DevTools → Application → Cookies).

```bash
curl -s -X POST "https://store.steampowered.com/api/removefromwishlist" \
  -H "Cookie: sessionid=$SESSION_ID; steamLoginSecure=$STEAM_LOGIN_SECURE" \
  -d "sessionid=$SESSION_ID&appid=$appid"
# Returns: {"success":true,"wishlistCount":N}
```

### ITAD lookup from Steam app ID

`https://isthereanydeal.com/app/{steamappid}/info/` redirects to the ITAD game page. Extract UUID from HTML:

```bash
url=$(curl -s -o /dev/null -w "%{url_effective}" -L "https://isthereanydeal.com/app/$appid/info/")
slug=$(echo "$url" | grep -o 'game/[^/]*' | cut -d/ -f2)
uuid=$(curl -s "https://isthereanydeal.com/game/$slug/info/" \
  | grep -o '"id":"[0-9a-f-]\{36\}"' | head -1 | grep -o '[0-9a-f-]\{36\}')
```

Games not on ITAD redirect back to the app page (no `game/` slug) — skip those.

---

## InfluxDB (personal time-series DB)

**Purpose:** Long-term personal time-series data — health metrics,
device telemetry, Claude Code token/cost, scraped counts (Gmail,
eBird, etc.). Backed by `observability-influxdb-1` on stockholm.

**Host:** `http://echobravoyahoo.net:8086` (LAN: `http://192.168.1.3:8086`)
**Org:** `echo-bravo-yahoo` (ID `83efdfbbd5a9fbdb`)
**Primary bucket:** `personal` (infinite retention)

**Auth:** `INFLUX_TOKEN` in `~/.secrets.env` (sourced by `~/.zshenv`).
The admin token also lives on stockholm at
`${CONFIG}/observability/observability.env` as `INFLUXDB_OPERATOR_TOKEN`;
pull with `ssh stockholm 'sudo -n grep INFLUXDB_OPERATOR_TOKEN ${CONFIG}/observability/observability.env'`
if needed. 1Password: `op://Seacattle/InfluxDB/password` (personal
account `my.1password.com`) — holds the web-UI login, not necessarily
the API token.

**CLI env (from `~/.zshenv`):**
```
INFLUX_ORG=echo-bravo-yahoo
INFLUX_HOST=http://echobravoyahoo.net:8086
INFLUX_PRECISION=s
```

**Measurements in bucket `personal`:**

| measurement              | source                                                  |
|--------------------------|---------------------------------------------------------|
| `bike`                   | `~/.aeby/scripts/report-bike.sh` (ad-hoc)               |
| `bloodPressure`, `bp`    | manual / `~/.aeby/scripts/report-bp.sh`                 |
| `claude-tokens`          | **legacy** — retired 2026-04-18; kept for history only  |
| `gmail`                  | `report-gmail-inbox.sh` (hourly cron)                   |
| `gut-pain`               | manual                                                  |
| `life-list`              | `report-ebird-life-list.sh`                             |
| `pinboard`               | `report-pinboard-counts.sh`                             |
| `prometheus_remote_write`| Alloy → Telegraf pipeline (Claude Code OTEL, + any future OTEL) |
| `ratingupdate`           | `report-rating-update.sh`                               |
| `syncthing`              | `report-syncthing-conflicts.sh` (30-min cron)           |
| `taskwarrior`            | `report-taskwarrior-tasks.sh`                           |
| `walk`, `weight`         | manual                                                  |

**What belongs:** time-varying personal metrics. One measurement per
source; use tags for dimensions, fields for values. Line-protocol writes
via `influx write -b personal '<line>' <ts>`. For OTEL-emitted metrics,
the Alloy pipeline lands them under `prometheus_remote_write` — see
`~/.claude/docs/claude-code-telemetry.md`.

**Query patterns:**
```bash
# Quick peek
influx query 'from(bucket:"personal") |> range(start:-7d) |> filter(fn:(r) => r._measurement == "gmail") |> limit(n:5)'

# List measurements in a bucket
influx query 'import "influxdata/influxdb/schema"
schema.measurements(bucket: "personal")'

# List field keys in a measurement
influx query 'from(bucket:"personal") |> range(start:-1h) |> filter(fn:(r) => r._measurement == "prometheus_remote_write") |> keep(columns:["_field"]) |> distinct(column:"_field")'

# Delete by predicate (RFC3339 times)
influx delete --bucket personal \
  --start 1970-01-01T00:00:00Z --stop 2030-01-01T00:00:00Z \
  --predicate '_measurement="smoketest"'
```

---

## Grafana (dashboards over InfluxDB + Loki)

**Purpose:** Personal-metric dashboards. Renders data out of InfluxDB
(time-series) and Loki (logs). Runs in `observability-grafana-1` on
stockholm.

**URLs:** LAN `http://192.168.1.3:3000` — external `https://data.echobravoyahoo.net`
**Auth:** Basic auth, user `aeby`. 1Password
`op://Seacattle/Grafana/user` + `op://Seacattle/Grafana/password`
(account `my.1password.com`).

**Existing dashboards** (all live on the Grafana instance —
`/api/search` is authoritative):
- `health` / `iot` / `personal` — pre-existing mixed-source
- `claude-code-usage` — Claude Code token & cost
- `pinboard` — Pinboard queue sizes and trends

**InfluxDB datasource** already wired up:
- UID: `be36rafk73dvke`
- Query language: Flux
- Internal URL (from Grafana's Docker network): `http://influxdb:8086`
- Default bucket: `default` (but Flux queries specify bucket explicitly)
- Token scope: org-wide read — `personal` bucket is readable

**What belongs:** dashboards visualizing InfluxDB (and, later, Loki)
data.

**Authoring convention: Grafana is the source of truth.** Author via
the API (`POST /api/dashboards/db`) or the UI. Grafana keeps internal
version history per dashboard (Dashboard settings → Versions); the
server copy is authoritative. **Do not commit dashboard JSON to a
local repo** — local files drift from the live dashboard within days,
invite merge conflicts, and never win against a click-ops edit on the
server. If you need a scratch JSON to POST, build it in `/tmp/` and
delete it after the POST succeeds.

**API patterns:**
```bash
GF_USER=$(op read 'op://Seacattle/Grafana/user' --account my.1password.com)
GF_PASS=$(op read 'op://Seacattle/Grafana/password' --account my.1password.com)

# Health check
curl -s -u "$GF_USER:$GF_PASS" http://192.168.1.3:3000/api/health

# Create/update a dashboard (POST body is {"dashboard": {...}, "overwrite": true})
curl -s -u "$GF_USER:$GF_PASS" -X POST -H "Content-Type: application/json" \
  --data @dashboard.json \
  http://192.168.1.3:3000/api/dashboards/db

# Export current state
curl -s -u "$GF_USER:$GF_PASS" \
  http://192.168.1.3:3000/api/dashboards/uid/<uid> | jq .
```

---

## ccq (Claude Code session query)

**Purpose:** Query Claude Code session transcripts as SQL. Every
session writes `~/.claude/projects/<slug>/<session-id>.jsonl`; `ccq`
loads them into an in-memory DuckDB database with pre-defined views.

**Tool:** `~/workspace/cc-query/` — installed as the `ccq` binary on
PATH. Also available as a `/cc-query:…` plugin set of skills.

**Auth:** none; reads files from disk. No network.

**Usage:**
```bash
# REPL: pipe SQL on stdin
ccq <<'SQL'
SELECT model, count(*) FROM token_usage GROUP BY model;
SQL

# Filter to a specific project dir
ccq ~/workspace/some-project <<'SQL'
SELECT sessionId, count(*) FROM token_usage GROUP BY sessionId;
SQL

# Use a specific session ID prefix
ccq -s abc123 <<'SQL'
SELECT * FROM messages LIMIT 5;
SQL
```

**Key views** (see `~/workspace/cc-query/docs/message-schema.md` for
the full schema):

| view            | columns                                                                                           |
|-----------------|---------------------------------------------------------------------------------------------------|
| `messages`      | full per-message record (role, content, toolUse, toolResult, timestamp, …)                        |
| `token_usage`   | `uuid`, `timestamp`, `sessionId`, `model`, `input_tokens`, `output_tokens`, `cache_read_tokens`, `cache_creation_tokens` |
| …               | additional views for tool calls, costs, plans — see docs                                          |

**What belongs:** questions you want to ask about your Claude Code
history — e.g., "which files did I edit most?", "how much did X cost?",
"which sessions used tool Y?". For persistent time-series storage,
pipe results into InfluxDB (see
`~/.claude/docs/claude-code-telemetry.md` for the backfill pattern).

**Common patterns:**
```sql
-- Sessions per day
SELECT date_trunc('day', timestamp) AS day, count(DISTINCT sessionId) AS sessions
FROM token_usage
GROUP BY day ORDER BY day DESC LIMIT 30;

-- Per-model token totals
SELECT model,
       SUM(input_tokens + output_tokens + cache_read_tokens + cache_creation_tokens) AS total_tokens
FROM token_usage GROUP BY model ORDER BY total_tokens DESC;

-- Window functions: running cumulative per (model, type)
WITH u AS (
  SELECT epoch_ns(timestamp) AS ts, model, input_tokens AS t FROM token_usage
)
SELECT ts, model,
       SUM(t) OVER (PARTITION BY model ORDER BY ts) AS cum
FROM u ORDER BY ts;
```

---

## Notes (`/mnt/d/Human Documents/notes/`)

Loose Johnny Decimal structure. Key folders:

| Folder | Purpose |
|--------|---------|
| `00-09 system/01 to-do` | Structured to-do (separate from Taskwarrior) |
| `10-19 life/15 job` | Career, job hunting, interview prep |
| `10-19 life/17 travel` | Travel notes |
| `10-19 life/19 purchase-research` | Per-SKU research for specific purchases |
| `20-29 digital/21 software` | Software docs and setup guides |
| `20-29 digital/21 software/21.08 reformat-and-wildflower` | New machine setup checklist |
| `20-29 digital/25 music` / `25 music-making` | Music content and production |
| `30-39 games/31 play` | Game backlog (non-purchase, non-Steam games) |
| `30-39 games/33 tools` | Game rulebooks and references |
| `40-49 food-drink-other/40 meta/40.01 inbox` | Food/drink inbox — recipes and ideas not yet processed |
| `40-49 food-drink-other/41 recipes` | Processed/tested recipes |
| `40-49 food-drink-other/43 homebrew` | Homebrewing and bitters |
| `50-59 3d-printing/51 queues` | 3D print job queue |
| `50-59 3d-printing/53 downloaded-models` | Downloaded STL model index |
| `70-79 reading-and-writing/73 books` | Books and reading lists |
| `70-79 reading-and-writing/73 books/73.02 to-read` | Active reading queue |

**Convention:** Never add a file to an index note without creating the file it refers to.

---

## Taskwarrior

See `~/.claude/docs/taskwarrior.md` for full reference.
**What belongs:** Actionable tasks with due dates, priorities, and project context.
**What doesn't belong:** Reference links (Pinboard), wishlists (Giftwhale), game lists (ITAD/notes).
