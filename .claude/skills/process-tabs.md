---
name: process-tabs
description: Launch interactive tab processor shell for Firefox tabs
---

Launch the tab processor CLI to process Firefox tabs using taskwarrior-style commands.

```bash
fftab
```

Tab listing reads Firefox's `recovery.jsonlz4` directly — instant, no extensions needed. Actions that modify the browser (close, process) lazily resolve real browser tab IDs via MCP on first use.

The shell provides these commands:
- `list` - Refresh and display all tabs
- `<IDs> process` - Process tabs with matched rules
- `<IDs> process:<task>` - Process with specific task
- `<IDs> new` - Create new rule for tabs
- `<IDs> close` - Close tabs
- `<IDs> skip` - Skip tabs from list
- `tasks` / `rules` - List configured items
- `exit` - Exit shell

ID syntax: `1`, `1-3`, `1 3 5`, `1-3 7`
