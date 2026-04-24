# Opening Ghostty Windows and Tabs

macOS + Ghostty only.

## New window in a directory

```bash
~/.aeby/scripts/ghostty-window.sh <dir> [command...]
```

- No command: opens a fresh shell in `<dir>`.
- With a command: joins the remaining args with spaces, runs them via `zsh -ic '…'` in `<dir>`, then drops to an interactive shell so the window stays open.

## "New tab" — currently aliased to a new window

```bash
~/.aeby/scripts/ghostty-tab.sh <dir> [command...]
```

This script prints a one-line warning and execs `ghostty-window.sh` with the same args. **It does not actually open a tab on macOS today.** Use it interchangeably with the window form when the user explicitly asks for a "tab" — Claude shouldn't need to remember which one to call.

### Why no real tab targeting on macOS

Ghostty's macOS apprt has no IPC channel, no `+new-tab` CLI action, and no per-pane env var like kitty's `KITTY_WINDOW_ID` or WezTerm's `WEZTERM_PANE`. The AppleScript dictionary exposes window/terminal `id`/`name`/`working directory` but not pane PID or tty, and `index`/`frontmost` on Ghostty windows are read-only. The only externally reachable hook for a new tab is `Cmd+T` via System Events keystroke, which targets whichever Ghostty window is frontmost when the script fires — unreliable when Claude invokes the script hours after the user last interacted with the terminal.

Tracking issue: <https://github.com/ghostty-org/ghostty/discussions/2353> ("Scripting API for Ghostty"). When that lands on macOS — likely a Unix-socket text protocol with a per-pane env var — rewrite `ghostty-tab.sh` to use it directly. Peer-terminal precedent: kitty (`kitten @ launch --type=tab --match id:$KITTY_WINDOW_ID`), WezTerm (`wezterm cli spawn --window-id …`).

## Pitfalls already encoded in the scripts

- Multi-token `-e` args without a shell wrapper produce `login: …: No such file or directory`. The window script wraps the user command in `zsh -ic '…'`.
- `Cmd+T` lands the new tab in `$HOME` because Ghostty's `window-inherit-working-directory = false`. Moot today since the tab script defers to a window — kept here for the future re-implementation.
- A window opened with `-e <cmd>` closes when `<cmd>` exits. The window script appends `; exec zsh -i` to keep the shell alive.
