---
name: open
description: "Open a file, URL, or resource in the appropriate application."
argument-hint: "<file-path or URL>"
---

# Open

Open a file, URL, or resource in the appropriate application based on its type.

## Steps

### 1. Classify the input

Determine the input type:

| Input | Type |
|-------|------|
| Starts with `http://` or `https://` | URL |
| `.md`, `.txt`, `.py`, `.js`, `.ts`, `.tsx`, `.jsx`, `.rs`, `.go`, `.sh`, `.bash`, `.zsh`, `.yaml`, `.yml`, `.json`, `.toml`, `.cfg`, `.conf`, `.env`, `.csv`, `.xml`, `.html`, `.css`, `.scss`, `.less`, `.lua`, `.rb`, `.c`, `.cpp`, `.h`, `.hpp`, `.java`, `.kt`, `.swift`, `.zig`, `.nix`, `.sql`, `.graphql`, `.proto`, `.vim`, `.el`, `.clj` | Text/code file |
| `.diff`, `.patch`, or a git ref (e.g., `HEAD~3`, a branch name, a commit hash) | Git ref/diff |
| `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.heic`, `.svg`, `.bmp`, `.tiff`, `.ico` | Image |
| `.pdf` | PDF |
| Anything else | Other |

### 2. Detect platform and open command

```bash
# Platform open command
if [ "$(uname)" = "Darwin" ]; then
  OPEN_CMD="open"
else
  OPEN_CMD="${commands -v xdg-open 2>/dev/null && echo xdg-open || echo open}"
fi
```

### 3. Open based on type

**URL:**

```bash
$OPEN_CMD "<url>"
```

**Text/code file or git ref/diff:**

Open in `$EDITOR` (default: `vim`) in a new terminal window.

Detect terminal and platform:

| Platform | `$TERM_PROGRAM` | Command |
|----------|-----------------|---------|
| macOS | `ghostty` | `open -na Ghostty --args --command="$EDITOR '<path>'"` |
| macOS | `Apple_Terminal` | `open -a Terminal "<path>"` |
| macOS | other/unset | `open -a Terminal "<path>"` |
| Linux | any | Launch `$EDITOR "<path>"` in a new terminal via the available emulator, or fall back to opening in the current shell |

For git refs, resolve to a temp file first:
```bash
git show <ref> > /tmp/<ref-name>.diff
# then open the temp file as a text file
```

**Image, PDF, or other:**

```bash
$OPEN_CMD "<path>"
```

### 4. Report

Print what was opened and which application/method was used.
