# Claude Code Telemetry → InfluxDB → Grafana

Claude Code emits OpenTelemetry metrics for token usage, cost, and
sessions. The personal setup routes them through `stockholm`'s
observability stack (Alloy → Telegraf → InfluxDB) and renders them in
a Grafana dashboard. This doc covers what's wired up, how to diagnose
it, and how to extend it.

## Architecture

```
Claude Code CLI (any LAN machine)
      │ OTLP/HTTP, http://stockholm:4318
      ▼
 observability-alloy-1 on stockholm (Grafana Alloy 1.4.3)
   otelcol.receiver.otlp
     → otelcol.processor.batch
     → otelcol.exporter.prometheus   (OTEL → Prom; dots→underscores)
     → prometheus.remote_write  →  http://telegraf:1234/receive
      │
      ▼
 observability-telegraf-1 on stockholm (Telegraf 1.32)
   inputs.http_listener_v2 (data_format=prometheusremotewrite, metric_version=2)
     → outputs.influxdb_v2
      │
      ▼
 observability-influxdb-1 (bucket: personal)
      │ Flux (existing datasource UID be36rafk73dvke)
      ▼
 observability-grafana-1 → dashboard `claude-code-usage`
```

Alloy is the OTEL ingress; it converts OTEL metrics to Prometheus
data-model samples and ships them via Prom remote-write. InfluxDB 2.x
OSS has no native Prom remote-write endpoint, so Telegraf sits between
Alloy and InfluxDB as a shim (`prometheusremotewrite` input →
`influxdb_v2` output).

## Schema

Telegraf's `prometheusremotewrite` parser runs in its default
`metric_version = 2` layout, so in InfluxDB:

- **measurement**: always `prometheus_remote_write` (one bucket for all
  Prom-remote-write ingest)
- **field key**: the metric name (e.g., `claude_code_token_usage_tokens_total`)
- **field value**: the cumulative counter sample
- **tags**: OTEL attributes, plus standard Prom labels (`instance`,
  `job`, `service_name`)

Key Claude Code fields:

| field key                              | unit   | tags                | notes                                |
|----------------------------------------|--------|---------------------|--------------------------------------|
| `claude_code_token_usage_tokens_total` | tokens | `model`, `type`     | `type` ∈ {input, output, cacheRead, cacheCreation} |
| `claude_code_cost_usage_USD_total`     | USD    | `model`             | estimated on-device                  |
| `claude_code_session_count_total`      | —      | —                   | incremented at session start         |

All three are monotonic Counters, `_total` and unit suffixes added by
the OTEL → Prom conversion.

## Claude Code env vars

`~/.zshenv` (tracked by dotfiles):

```bash
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
export OTEL_EXPORTER_OTLP_ENDPOINT=http://stockholm:4318
export OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE=cumulative
export OTEL_METRIC_EXPORT_INTERVAL=10000   # ms; 10s during validation, bump to 60000 after
```

**Gotcha**: `~/.claude/settings.json` must NOT set
`CLAUDE_CODE_DISABLE_TELEMETRY=1` in its `env` block. That setting
takes precedence over shell env vars and silently disables all OTEL
export. If no metrics are landing, check `jq '.env' ~/.claude/settings.json`
first.

The temporality override (`cumulative`) matters because Claude Code
defaults to *delta* temporality, but Alloy's Prom exporter expects
cumulative input. Delta input produces garbage samples.

## Stockholm configuration

stockholm is a Raspberry Pi running OpenMediaVault (ARM64/aarch64).
SSH: key-auth as `pi` (`ssh stockholm`); `sudo -n` is passwordless.
Everything in this section lives under
`${CONFIG}=/srv/dev-disk-by-uuid-46f8fb21-c919-493f-b366-a6c898ce4c2f/config`
and `${CONTENT}=/srv/…/content` (those vars are defined in
`${CONFIG}/global.env`).

### Container images

**No custom images.** The pipeline runs upstream, unmodified:

- `grafana/alloy:v1.4.3` (multi-arch; arm64/v8 variant used here)
- `telegraf:1.32` (InfluxData official; multi-arch)
- `influxdb:latest` (pre-existing OMV-managed)
- `grafana/grafana:11.3.0` (pre-existing OMV-managed)

No Dockerfile, no build step. To update a component, bump the tag in
the owning compose file and pull:

```bash
# Alloy (in observability.yml — OMV-managed, edit via OMV GUI)
# Telegraf (in ~telegraf/compose.yml — edit directly)
ssh stockholm '
  cd /srv/dev-disk-by-uuid-46f8fb21-c919-493f-b366-a6c898ce4c2f/config/telegraf
  sudo -n docker compose \
    --env-file /srv/dev-disk-by-uuid-46f8fb21-c919-493f-b366-a6c898ce4c2f/config/global.env \
    --env-file /srv/dev-disk-by-uuid-46f8fb21-c919-493f-b366-a6c898ce4c2f/config/observability/observability.env \
    -f compose.yml pull
  sudo -n docker compose … -f compose.yml up -d
'
```

### Docker Compose files (two of them)

Two distinct compose stacks run in parallel on stockholm. **They are
not merged** — no `-f a.yml -f b.yml` pattern. Each stack owns its own
services and shares networks via `external: true`.

**1. `${CONFIG}/observability/observability.yml` — OMV-auto-generated.**
Owns `influxdb`, `grafana`, `loki`, `alloy`. Regenerated by
OpenMediaVault whenever the user changes the observability stack via
the OMV GUI. **Do not hand-edit** — the auto-generated header warns
about this. Services are authored by editing via
`OMV → Services → Compose → Files → observability` in the UI.

The Alloy service block (verbatim from `observability.yml`):

```yaml
alloy:
  image: grafana/alloy:v1.4.3
  networks:
    - private
  ports:
    - "4317:4317"      # OTLP/gRPC
    - "4318:4318"      # OTLP/HTTP — Claude Code posts here
    - "12345:12345"    # Alloy HTTP UI + /-/reload endpoint
  command: run --server.http.listen-addr=0.0.0.0:12345 --storage.path=/var/lib/alloy/data /etc/alloy/config.alloy
  depends_on:
    - influxdb
  volumes:
    - "${CONFIG}/alloy:/etc/alloy"                # mounts config.alloy
    - "${CONTENT}/alloy/data:/var/lib/alloy/data" # WAL + component state
    - "${CONTENT}/alloy/logs:/tmp/app-logs"
```

The `restart: unless-stopped` policy is applied by OMV at stack level.

**2. `${CONFIG}/telegraf/compose.yml` — hand-written.** Owns Telegraf
only. Separate stack so OMV doesn't regenerate over our changes.
Joined to the `private` bridge network as `external: true` so it can
resolve `influxdb` by service name:

```yaml
services:
  telegraf:
    image: telegraf:1.32
    container_name: observability-telegraf-1
    restart: unless-stopped
    networks:
      - private
    volumes:
      - "${CONFIG}/telegraf/telegraf.conf:/etc/telegraf/telegraf.conf:ro"
    environment:
      - INFLUX_TOKEN=${INFLUXDB_OPERATOR_TOKEN}

networks:
  private:
    name: private
    external: true
```

No ports are published — Telegraf is only reachable from other
containers on `private`, specifically Alloy.

### Networks

Two docker bridge networks are relevant:

| network          | purpose                                | members                                         |
|------------------|----------------------------------------|-------------------------------------------------|
| `private`        | internal comms between stack services  | `influxdb`, `grafana`, `loki`, `alloy`, `telegraf` |
| `echobravoyahoo` | externally-reachable services          | `influxdb`, `grafana` (for reverse-proxy ingress) |

Service-name DNS works within each network. So from inside Alloy,
`http://telegraf:1234/receive` resolves to the Telegraf container,
and from inside Telegraf, `http://influxdb:8086` resolves to InfluxDB.
None of this is published to the LAN except the deliberate port maps
on `alloy` (4317/4318/12345), `grafana` (3000), and `influxdb` (8086).

### Env file chain

The compose substitution `${VAR}` resolves from these env files, in
order:

1. **`${CONFIG}/global.env`** — machine-wide. Defines `CONFIG` and
   `CONTENT` (the volume-mount roots). Loaded by OMV for every stack
   it manages, and passed explicitly to our hand-written Telegraf
   stack via `--env-file`.
2. **`${CONFIG}/observability/observability.env`** — observability-
   specific. Defines `INFLUXDB_OPERATOR_TOKEN`, `INFLUXDB_USERNAME`,
   `INFLUXDB_PASSWORD`. Used by `observability.yml` and passed to the
   Telegraf stack.

Bringing up Telegraf needs both files:

```bash
docker compose \
  --env-file ${CONFIG}/global.env \
  --env-file ${CONFIG}/observability/observability.env \
  -f ${CONFIG}/telegraf/compose.yml up -d
```

### Config files on disk

The OMV-managed Alloy container mounts `${CONFIG}/alloy/` → `/etc/alloy`.
Our hand-written Telegraf container mounts
`${CONFIG}/telegraf/telegraf.conf` → `/etc/telegraf/telegraf.conf`.

**`${CONFIG}/alloy/config.alloy`** (also in
`~/workspace/claude-otel-alloy/config.alloy` on the Mac for editing):

```alloy
logging {
  level  = "info"
  format = "logfmt"
}

otelcol.receiver.otlp "default" {
  grpc { endpoint = "0.0.0.0:4317" }
  http { endpoint = "0.0.0.0:4318" }

  output {
    metrics = [otelcol.processor.batch.default.input]
  }
}

otelcol.processor.batch "default" {
  timeout         = "10s"
  send_batch_size = 8192

  output {
    metrics = [otelcol.exporter.prometheus.default.input]
  }
}

otelcol.exporter.prometheus "default" {
  resource_to_telemetry_conversion = true
  forward_to = [prometheus.remote_write.influx.receiver]
}

prometheus.remote_write "influx" {
  endpoint {
    url = "http://telegraf:1234/receive"
  }
}
```

Backups of previous versions live at `${CONFIG}/alloy/config.alloy.bak.<ts>`.

**`${CONFIG}/telegraf/telegraf.conf`** (also in
`~/workspace/claude-otel-alloy/telegraf.conf`):

```toml
[agent]
  interval        = "10s"
  flush_interval  = "10s"
  omit_hostname   = true

[[inputs.http_listener_v2]]
  service_address = ":1234"
  paths           = ["/receive"]
  data_format     = "prometheusremotewrite"

[[outputs.influxdb_v2]]
  urls         = ["http://influxdb:8086"]
  token        = "${INFLUX_TOKEN}"
  organization = "echo-bravo-yahoo"
  bucket       = "personal"
```

(Telegraf 1.32 doesn't accept `metric_version` as a plugin option on
`inputs.http_listener_v2` — attempts to set it fail config parsing.
Default is v2 layout, which is what the schema section above assumes.)

### Data flow on-box

```
Mac (any LAN host)
  │  POST /v1/metrics  (OTLP/HTTP, protobuf)
  ▼
stockholm:4318  (docker-proxy on host)
  │  → private network
  ▼
observability-alloy-1
  │  otelcol.receiver.otlp           (accepts OTLP on :4318 & :4317)
  │  → otelcol.processor.batch       (buffer 10s / 8192 samples)
  │  → otelcol.exporter.prometheus   (OTEL data model → Prom samples;
  │                                    dots→underscores, adds _total / _USD / _tokens suffixes,
  │                                    resource attrs promoted to labels)
  │  → prometheus.remote_write       (Prom remote-write protocol over HTTP)
  │  POST /receive  (snappy-compressed protobuf)
  ▼
telegraf:1234  (service DNS inside `private`)
  │  inputs.http_listener_v2         (decodes Prom remote-write body)
  │  → outputs.influxdb_v2           (writes line protocol)
  │  POST /api/v2/write  (Authorization: Token <INFLUXDB_OPERATOR_TOKEN>)
  ▼
influxdb:8086  (service DNS inside `private`)
  │  → /api/v2/write handler
  ▼
${CONTENT}/influxdb/…  (TSM files on disk)
      │
      │  Flux queries via datasource (Grafana → internal http://influxdb:8086)
      ▼
observability-grafana-1  → `claude-code-usage` dashboard
```

### Operations

**Start/stop/restart the whole observability stack** — via OMV GUI
(Services → Compose → Files → observability). Includes Alloy.

**Start/stop Telegraf on its own:**
```bash
cd ${CONFIG}/telegraf
docker compose --env-file ${CONFIG}/global.env \
               --env-file ${CONFIG}/observability/observability.env \
               -f compose.yml up -d        # start / recreate
docker compose … -f compose.yml down       # stop + remove
docker compose … -f compose.yml restart    # restart in place
```

**Alloy config changes** — two options:

1. **Full restart**: write new `config.alloy`, then
   `docker restart observability-alloy-1`. Simpler, ~5-10s downtime.
   WAL replay on startup means queued samples survive.
2. **Hot reload**: `curl -X POST http://stockholm:12345/-/reload`
   (Alloy's built-in reload endpoint — exposed by the `--server.http.listen-addr`
   flag in the compose command). No restart, faster iteration for
   config development.

**Telegraf config changes** — always restart
(`docker restart observability-telegraf-1`). Telegraf has no hot
reload for http_listener_v2.

**Tail logs live:**
```bash
docker logs -f observability-alloy-1
docker logs -f observability-telegraf-1
```

Alloy's logs are very chatty at `info` level; grep for `error` /
`Exporter` / `remote_write` to focus.

**Backup/restore Alloy config** — every deploy leaves a `.bak.<ts>`
next to `config.alloy`. Restore: `cp <bak> config.alloy` then
`docker restart observability-alloy-1`.

### Extending to other OTEL sources

Anything that can speak OTLP/HTTP to `stockholm:4318` will flow
through the same Alloy pipeline and land as
`measurement=prometheus_remote_write` in the `personal` bucket with
the metric name as field key. To add another source:

1. Point it at `http://stockholm:4318` (protocol `http/protobuf`).
2. Ensure cumulative temporality if the source is a Claude-style
   delta emitter (`OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE=cumulative`).
3. Query in Grafana by the new metric's field key.

No Alloy or Telegraf config changes needed per new source.

## Dashboard

- URL: http://192.168.1.3:3000/d/claude-code-usage/claude-code-usage
- JSON source: `~/workspace/grafana-dashboards/claude-code-usage.json`
- Datasource: InfluxDB, UID `be36rafk73dvke`, Flux
- All panels use `difference(nonNegative: true) |> sum()` to convert
  cumulative counters into per-window deltas. `nonNegative: true`
  silently drops negative deltas at counter resets (session starts),
  so discontinuities never show up as spikes.

## Historical backfill

Session transcripts on disk (`~/.claude/projects/**/*.jsonl`) contain
per-request token counts going back to the start of Claude Code use.
They can be replayed into the same schema via:

- SQL: `~/workspace/claude-otel-alloy/backfill.sql`
- Tool: `ccq` (reads transcripts into DuckDB; see
  `~/.claude/docs/information-stores.md` §ccq)
- Invoke: `ccq < backfill.sql | tail -n +2 | influx write --bucket personal --precision ns`

The SQL emits monotonic cumulative counters per (model, type) and per
model-for-cost, using a baked-in pricing table and stripping
`-YYYYMMDD` date suffixes from model names so tags match live data.

If re-running: `influx delete --bucket personal --start 1970-01-01T00:00:00Z --stop <now> --predicate '_measurement="prometheus_remote_write"'`
first, then re-pipe. That wipes any live data alongside the old
backfill — a small price if you're regenerating anyway.

## Diagnosing

| Symptom | Where to look |
|---------|--------------|
| No `claude_code_*` fields in bucket | `jq '.env' ~/.claude/settings.json` for the disable flag; `env | grep CLAUDE_CODE` and `env | grep OTEL_` |
| OTLP endpoint unreachable | `curl -i http://stockholm:4318/v1/metrics` should 405; if not, check `docker ps` on stockholm and `docker logs observability-alloy-1` |
| Metrics reach Alloy but not InfluxDB | `docker logs observability-telegraf-1` for parser errors; verify `INFLUX_TOKEN` env in the Telegraf container |
| Dashboard shows $0 but bucket has data | field name drift — verify field keys via `influx query 'from(bucket:"personal") |> range(start:-1h) |> filter(fn:(r) => r._measurement == "prometheus_remote_write") |> keep(columns:["_field"]) |> distinct(column:"_field")'` |

## Residual risk

**Off-LAN metric loss** — Claude Code sessions run anywhere (coffee
shops, airplanes) lose metrics because `stockholm:4318` is LAN-only.
OTEL SDK doesn't persist OTLP export queues to disk. To close: publish
Alloy via Tailscale or Caddy+auth. Tracked as taskwarrior item 631.
