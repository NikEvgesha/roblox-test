# GPT Journal (RobloxProject)

Start date: `2026-03-15`
Project path: `E:\GitFork\RobloxProject`

## Current Snapshot

- Team size: `3`
- Collaboration mode: `Roblox Team Create + Git + Linear`
- Main risk: world changes done in Studio without changelog/issue linkage

## Session Log

### 2026-03-15

- What changed:
  - initialized git repository;
  - created project folder structure (`src/server`, `src/client`, `src/shared`, `Docs`);
  - added base workflow docs and changelog templates;
  - added Rojo mapping scaffold and starter scripts.
- Why it matters:
  - team now has one documented process for code, world changes, and task tracking.
- What is next:
  - configure Rojo in each developer environment;
  - align Linear board with statuses/labels policy.
- Verification:
  - file structure created and visible in repository root.

### 2026-03-15 (Rojo-only migration)

- What changed:
  - migrated script file naming to Rojo conventions (`*.server.lua`, `*.client.lua`, `*.lua`);
  - switched docs/process from mixed sync to Rojo-only setup (`Docs/ROJO_SETUP.md`);
  - updated `default.project.json` mapping to direct service-level paths;
  - added `aftman.toml` to pin Rojo CLI version.
- Why it matters:
  - all developers now use one consistent code sync pipeline, reducing sync drift and merge mistakes.
- What is next:
  - each developer runs `aftman install` and validates `rojo serve` connection from Studio plugin.
- Verification:
  - repository contains renamed script files and updated setup docs.
