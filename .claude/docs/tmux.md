# tmux

After editing `~/.tmux.conf`, reload with:
```bash
tmux source-file ~/.tmux.conf
```

When adding keybindings, always check if the key has a default tmux binding. Prompt before overwriting standard bindings.

## Sockets

Two tmux servers in use:

- **default socket** (no `-L`): `claudes` session and day-to-day work. Standard config at `~/.tmux.conf`, prefix `C-a`, cyan accent.
- **`-L inner`**: Claude Code multi-agent workflow sessions, intended to be embedded as a nested client inside a `claudes` pane. Config at `~/.tmux.inner.conf`, prefix `C-b`, orange accent. Use the `tmux-inner` shell helper (defined in `~/.config/ashton/functions.zsh`).

Agent workflow scripts (`~/.aeby/scripts/dispatch-experiment.sh`, `dispatch-experiment-cleanup.sh`) target the `inner` socket via `DISPATCH_TMUX_SOCKET` (defaults to `inner`).

Embedding a workflow in `claudes`: from a pane in `claudes`, run `tmux-inner attach -t <workflow>`. Outer prefix (`C-a`) drives `claudes`; inner prefix (`C-b`) drives the workflow.
