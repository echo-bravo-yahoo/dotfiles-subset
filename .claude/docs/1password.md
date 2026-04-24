# 1Password CLI (`op`) in olapui

## npm auth (automatic)

npm auth for `@vlognow` packages is handled automatically by the `preinstall` hook (`scripts/ensure-npm-auth.js`). On first `npm install` in a fresh clone, it fetches the token from 1Password and writes it to `~/.npmrc`. No manual `op run` wrapper needed.

To re-fetch a stale token:
```bash
node scripts/ensure-npm-auth.js --force
```

## Account flag

The `Shared - UI-Team` vault is on the `machinify.1password.com` account, not the personal `my.1password.com` account. Scripts that still use `op run` (like `cypress`) need `--account`:

```bash
op run --account machinify.1password.com --env-file="./dev.env" -- cypress open
```

## Caching credentials

Every `op` read triggers biometric auth. Caching strategy depends on where you're running.

### Inside Claude Code — use `cc-cred run`

The Bash tool spawns a fresh zsh for every call, so exported env vars don't survive across Bash invocations — a tight loop re-fetches on every iteration and fires the biometric prompt each time. `cc-cred` solves this by caching under the current `c` session's state dir:

```bash
cc-cred run MY_TOKEN=op://Shared-UI-Team/foo/credential -- <cmd>
cc-cred run --account machinify.1password.com \
  MY_TOKEN=op://Shared-UI-Team/foo/credential \
  OTHER=op://Private/bar/password \
  -- ./my-script.sh
```

First call: `op read` fetches, cache is populated at `~/.c/state/<session-id>/creds/<NAME>` (file `0600`, dir `0700`), then the child `exec`s with `NAME=<value>` in its env. Subsequent calls: read cached value directly — no biometric prompt. The value never transits the Bash tool's stdout, so it doesn't land in the CC transcript.

- **Session-scoped.** `cc-cred` resolves the session via `c state-dir`, which walks process ancestry to the `claude` PID and intersects with `~/.c/index.toml`. This only works for sessions started via `c new` / `c resume` (ephemeral or raw `claude` invocations aren't tracked — `cc-cred` exits non-zero with a clear message).
- **Sibling agents share the cache.** Sub-agents within the same session share ancestry back to the same `claude` PID, so they hit the same creds dir — first agent pays the `op read`, the rest read cache.
- **How isolation works.** Same-UID peer sessions can't isolate each other via OS filesystem permissions, so cc-allow enforces it: `read.deny` / `write.deny` / `edit.deny` rules on `path:$HOME/.c/state/*/creds/**` block direct `cat`/`Read`/`Write`/`Edit` access through CC tools. `cc-cred` is the only allowed reader, and it only ever opens its own session's dir. See `cc-allow.md` for rule details.
- **Lifecycle.** The cache dir is deleted when the session ends (via `c hook session-end`). If the session crashes, `c`'s `reconcileStaleSessions` sweeps the orphan on the next `c` session start.

`cc-cred` subcommands: `run` (primary), `set` (pre-fetch only), `list` (cached names — values never printed), `purge` (delete this session's creds), `session` (print resolved session id).

### Outside Claude Code — the env-var default pattern

For interactive shells, `op run` wrappers, or scripts you invoke yourself, the POSIX default-value trick is still the right move:

```bash
export MY_TOKEN="${MY_TOKEN:-$(op item get <item-id> --account <account> --fields credential --reveal)}"
```

First call fetches via `op`; subsequent calls in the same shell skip the subshell because `MY_TOKEN` is already set. Standard `${param:-word}` expansion — bash 3.2+, zsh, sh.

## WSL2 bridge

The `op` CLI and SSH agent work in WSL2 via a socat + npiperelay bridge to the Windows 1Password app. Full setup guide: `notes/21.01 wsl/1password-cli.md`.

Current state:
- Socket: `~/.1password/agent.sock` (maintained by `1password-app-integration.service`)
- `SSH_AUTH_SOCK` set in `.zshrc` — SSH agent works automatically
- `op signin` requires an interactive terminal (TTY); subsequent commands work non-interactively for ~10 minutes
- If the socket goes missing: `systemctl --user restart 1password-app-integration.service`

## Diagnostics

```bash
op account list          # shows all configured accounts
op vault list --account machinify.1password.com  # verify vault exists
```
