# Node.js / JavaScript / TypeScript

## Package Manager

Default to `npm`. Respect project-level overrides in this priority order:

1. **`packageManager` field** in `package.json` (Corepack spec, e.g. `"packageManager": "pnpm@8.15.0"`) — definitive
2. **Lock file** — `yarn.lock` → yarn, `pnpm-lock.yaml` → pnpm, `bun.lockb`/`bun.lock` → bun
3. **Neither present** → use `npm`

Do not use `yarn`, `pnpm`, or `bun` unless one of the above signals is present.

## Linting

Use the project's linter. Neovim uses `eslint_d` (fast daemon wrapper around `eslint`).

- If `eslint.config.*` or `.eslintrc*` exists → `eslint`
- If `biome.json` exists → `biome lint`
- If neither exists → prefer `biome lint` (zero-config)
- `oxlint` if the project uses it

## Formatting

Respect the project formatter. Neovim uses `prettier` via vim-prettier (autoformat, config precedence: prefer-file).

- Check for `.prettierrc*`, `prettier.config.js`, `.prettierrc.toml` → `prettier`
- Check for `biome.json` → `biome format`
- Project config always takes precedence over defaults

## Type Checking

`tsc --noEmit` — run after linting when a `tsconfig.json` is present.

## npm link with fnm

`fnm` auto-switches Node versions per repo (via `.nvmrc` / `.node-version`). Global `npm link` registers under the active Node version's prefix. If two repos use different versions, the consumer can't find the producer's link.

Use `npm link <path>` instead of the two-step global approach:

```bash
# Instead of:
#   cd producer && npm link        # registers globally under Node vX
#   cd consumer && npm link <pkg>  # looks globally under Node vY — not found

# Do:
cd consumer
npm link /absolute/path/to/producer/package
```

This creates a direct symlink in `node_modules/` without going through the global prefix.

### mac-ui → olapui worktree link setup

1. Build mac-ui:
   ```bash
   cd ~/workspace/mac-ui/.claude/worktrees/<name>
   npm install
   npm run --workspace @vlognow/mac-ui create-version-module  # generates src/version.ts
   cd packages/mac-ui && npx tsc -b                           # compile to dist/
   ```
   Note: `npm run build:base` (lerna) may fail on the postbuild `cem` step (lightningcss native module). Running `tsc -b` directly produces the needed `dist/` output.

2. Install olapui deps (preinstall hook auto-configures npm auth via 1Password):
   ```bash
   cd ~/workspace/olapui/.claude/worktrees/<name>
   npm install
   ```

3. Link (direct path, avoids fnm version mismatch):
   ```bash
   npm link ~/workspace/mac-ui/.claude/worktrees/<name>/packages/mac-ui
   ```

4. Verify:
   ```bash
   ls -la node_modules/@vlognow/mac-ui
   # Should show symlink → mac-ui worktree path
   ```
