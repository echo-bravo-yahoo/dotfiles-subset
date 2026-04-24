# Cron conventions

Where a scheduled job runs matters. The Mac sleeps; `stockholm`
(Raspberry Pi NAS) doesn't. Scheduling a personal-data ingest on the
Mac guarantees gaps in the data every time the lid closes.

## Rule

**Device-agnostic cron jobs run on `pi@stockholm`.** Device-specific
jobs stay on the Mac.

A job is *device-agnostic* when it could run on any always-on host
and produce the same output — e.g., hitting a remote API (Pinboard,
Gmail, eBird), reading InfluxDB, filing a report. These belong on
stockholm.

A job is *device-specific* when it needs macOS state — Keychain, an
AppleScript-driven app, a mounted iCloud file, Homebrew paths. These
stay on the Mac (`crontab -e` on the Mac).

Decision in one sentence: *"Would this job's output be identical if
it ran on stockholm instead?"* If yes, move it to stockholm.

## Stockholm layout

- Scripts: `/home/pi/.aeby/scripts/` (mirrors `~/.aeby/scripts/` on
  the Mac; currently deployed manually via `rsync`, not via a
  dotfiles clone).
- Logs: `/home/pi/logs/` (stderr + stdout from each job).
- Crontab: `pi`'s user crontab (`ssh stockholm crontab -e`).
- Shell: bash (not zsh) — so scripts must not rely on `~/.zshenv`
  being read. Source `~/.secrets.env` directly; see
  `~/.claude/docs/dotfiles.md` §Secrets.

## Inventory (as of 2026-04-19)

stockholm (`pi`'s crontab):
- `*/2  * * * *` — `task sync`
- `*/10 * * * *` — `report-taskwarrior-tasks.sh`
- `*/10 * * * *` — `report-gmail-inbox.sh`
- `*/30 * * * *` — `report-rating-update.sh`
- `7 * * * *`   — `report-pinboard.sh` (this plan)

Mac (`crontab -l`): backups and syncthing-conflict checks that touch
local filesystem state.

## Adding a new stockholm cron job

1. Make the script portable: no `$OSTYPE`-gated Homebrew paths, no
   `source ~/.zshenv` (use `~/.secrets.env` directly).
2. Deploy it to `/home/pi/.aeby/scripts/` (currently `rsync` — no
   automatic sync).
3. Verify deps on stockholm: `ssh stockholm 'which influx jq curl'`
   (plus anything script-specific).
4. Pick a minute offset that doesn't collide with existing entries
   (the current grid is `2/3/7/10/30` past the hour).
5. Append via `ssh stockholm 'crontab -l > /tmp/bak.$(date +%s);
   (crontab -l; echo "<entry>") | crontab -'` — atomic add.
6. Tail the log once to confirm the first fire: `ssh stockholm 'tail
   -f ~/logs/<script>.log'`.

## Notes

- Stockholm's `crontab -l` does not need `PATH` prepended; standard
  Debian PATH includes `/usr/local/bin` where `influx` lives.
- Jobs that already run on stockholm follow the `*/N` or `N */H`
  pattern and redirect to `~/logs/<script>.log` with a trailing
  `|| echo "… failed — check log" >&2` so cron mail fires on failure.
