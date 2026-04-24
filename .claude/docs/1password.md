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

Every `op item get` call triggers biometric auth. To avoid repeated prompts within a session, wrap the fetch in a default-value expansion:

```bash
export MY_TOKEN="${MY_TOKEN:-$(op item get <item-id> --account <account> --fields credential --reveal)}"
```

- **First call**: `MY_TOKEN` is unset, so the `op` subshell runs and the result is exported.
- **Subsequent calls**: `MY_TOKEN` is already set, so `op` is never invoked.

This is standard POSIX `${param:-word}` expansion — works on bash 3.2+, zsh, and sh.

**Agent dispatch**: agents don't inherit env vars. Include the same `export` line in the agent prompt — the parent session's cached value won't help, but each agent only calls `op` once.

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
