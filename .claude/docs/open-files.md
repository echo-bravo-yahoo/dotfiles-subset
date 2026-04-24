# Opening Files

## File Type Routing

| File type | Handler | Notes |
|-----------|---------|-------|
| Source code (`.ts`, `.js`, `.py`, `.rs`, `.go`, `.lua`, `.sh`, `.toml`, `.yaml`, `.json`, `.html`, `.css`, etc.) | nvim | |
| Markdown (`.md`) | nvim | |
| Plain text (`.txt`, `.log`, `.env`, `.conf`, `.ini`, `.cfg`) | nvim | |
| Directories (of code/projects) | nvim | Opens netrw/oil/file explorer |
| URLs (`https://...`) | `open` / `xdg-open` | Opens in default browser |
| Images (`.png`, `.jpg`, `.jpeg`, `.gif`, `.svg`, `.webp`, `.ico`) | `open` / `xdg-open` | Opens in OS image viewer |
| PDFs (`.pdf`) | `open` / `xdg-open` | Opens in OS PDF viewer |
| Office docs (`.docx`, `.xlsx`, `.pptx`, `.csv`) | `open` / `xdg-open` | Opens in default app |
| Archives (`.zip`, `.tar`, `.gz`) | `open` / `xdg-open` | Opens in Finder/file manager |
| Everything else / unknown | `open` / `xdg-open` | Fallback to OS default |

## Environment Detection

```bash
# Detect tmux
[ -n "$TMUX" ]

# Detect OS for open command
case "$(uname)" in
  Darwin) OPEN_CMD="open" ;;
  *)      OPEN_CMD="xdg-open" ;;
esac
```

## nvim: How to Open by Environment

**In tmux (single file):**

```bash
tmux new-window -n "<short-name>" "nvim <path>"
```

**In tmux (multiple files):**

```bash
tmux new-window -n "<short-name>" "nvim <path1> <path2> <path3>"
```

All files open as buffers in one nvim instance, in one tmux window. **Never** open multiple tmux windows or nvim instances for a single request — pass all paths as arguments to one nvim command.

**Not in tmux (Ghostty on macOS, single file):**

```bash
open -na Ghostty.app --args --quit-after-last-window-closed=true -e nvim <path>
```

**Not in tmux (Ghostty on macOS, multiple files):**

```bash
open -na Ghostty.app --args --quit-after-last-window-closed=true -e nvim <path1> <path2> <path3>
```

**Not in tmux (Linux — WSL2 with Windows Terminal):**

```bash
~/.aeby/scripts/wt-nvim.sh "<path>" ["<path2>" ...]
```

The script prefers an existing tmux session (opens a new window there); falls back to a new Windows Terminal tab via `wt.exe`. The full nvim path is hardcoded in the script — update it there if nvim moves. This script is allowed by cc-allow via the `aeby-scripts` alias.

**Not in tmux (Linux — generic terminal):**

Suggest the user the command; copy to clipboard if possible.

## OS Default App: How to Open

```bash
# macOS
open <path-or-url>

# Linux
xdg-open <path-or-url>
```

## Rules for nvim (code, markdown, text, directories)

- **Never** run nvim as a foreground Bash command — the Bash tool has no TTY, so nvim will hang
- **Never** background nvim with `&` — it still won't have a TTY to attach to
- **Never** use `open <file>` for code/text files — macOS routes them to GUI editors (TextEdit, Xcode, etc.)
- In tmux, use `tmux new-window`, not `tmux split-pane` (splits are too small for editing)
- Pass `-n <short-name>` to `tmux new-window` to name the window after the file (e.g., `tmux new-window -n brag-sheet "nvim /path/to/brag-sheet.md"`)
- **Multiple files = one command.** When opening multiple files, pass all paths to a single nvim invocation. Never spawn separate terminal windows or nvim instances per file.
- **Always invoke `nvim` explicitly — never `vim`.** The user's zsh aliases `vim=nvim` in `~/.zshrc`, but Ghostty's `--args -e` (and any `--command=` variant) executes the command in a non-interactive shell that does **not** source `.zshrc`, so the alias is not defined. Running `vim` there launches the system's real vim, which has no config and broken behavior. Use `-e nvim <path>` directly.

## Rules for OS-default files (images, PDFs, URLs, office docs, archives, unknown types)

- `open` / `xdg-open` is non-interactive — safe to run directly from the Bash tool
- No special tmux handling needed; these launch external GUI apps regardless of environment
