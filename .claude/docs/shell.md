# Shell (Bash / Zsh)

## Linting

`shellcheck` — run on any bash/sh scripts written or modified.

Neovim uses `bashls` LSP with `shellcheckArguments = "--shell=bash"` and filetypes `sh`, `zsh`, `bash`.

## Portability notes

See the "Bash Portability" section in `~/.claude/CLAUDE.md` for cross-platform scripting rules (macOS + Linux).

## Avoid the `command` invocation wrapper

`command <name> [args]` runs `<name>` while bypassing shell functions and aliases. cc-allow's evaluator sees only the literal `command` token — it does **not** parse through to the wrapped target, so any allow/deny rules on the real command (e.g., `sudo`, `dd`) are skipped. This makes `command <name>` a full allowlist bypass.

Only `command -v <name>` (and `-V`) is safe: these are lookups that never execute the target, and the global config allows them explicitly via `args.all = ["flags:v"]`.

Rules:
- **Lookup**: `command -v foo` — fine, use freely for feature detection.
- **Execution**: never use `command foo [args]`. Call `foo` directly. If a shell function is shadowing the binary, invoke by absolute path (`/usr/bin/foo`) or `\foo` to bypass aliases without the wrapper.
