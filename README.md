# RobloxProject

Team Roblox project with hybrid source-of-truth and a Rojo-first code pipeline:

- `Git` is source-of-truth for code, configs, docs, and process.
- `Roblox Studio cloud` is source-of-truth for world/scene/assets and published places.
- `Linear` is source-of-truth for planning, priorities, and task status.

## Repository Layout

- `src/lobby/server` -> lobby server scripts
- `src/lobby/client` -> lobby client scripts
- `src/combat/server` -> combat server scripts
- `src/combat/client` -> combat client scripts
- `src/shared` -> shared modules
- `Docs` -> workflow, setup, changelogs, and quality docs
- `default.project.json` -> default Rojo mapping (combat)
- `lobby.project.json` -> lobby Rojo mapping
- `combat.project.json` -> combat Rojo mapping
- `aftman.toml` -> pinned CLI tool versions

## Quick Start

1. Open Roblox Studio and publish the place under Group ownership.
2. Keep Team Create/Collaborate enabled.
3. Install Rojo and plugin using `Docs/ROJO_SETUP.md`.
4. Run `rojo serve` from repository root and connect plugin in Studio.
5. Use the right project file:
   - lobby place: `rojo serve lobby.project.json --port 34872`
   - combat place: `rojo serve combat.project.json --port 34873`
6. Edit scripts only in local files (`src/*`) and let Rojo sync.
7. Log world-only changes in `Docs/WORLD_CHANGELOG.md`.
8. Track every task in Linear and link issue IDs in commits/changelog.

## Rojo Conventions

1. `*.server.lua` -> `Script`
2. `*.client.lua` -> `LocalScript`
3. `*.lua` -> `ModuleScript`
4. Do not edit Rojo-managed scripts directly in Studio.
5. Do not use Script Sync in this repository.

## Commands

```powershell
aftman install
rojo serve combat.project.json --port 34873
rojo serve lobby.project.json --port 34872
```

## Team Rules

1. One Linear issue per concrete task.
2. One branch per issue: `feat/IGR-123-short-name` or `fix/IGR-123-short-name`.
3. No direct pushes to `main`.
4. Close issue only after:
   - behavior verified in Studio,
   - docs/changelog updated,
   - code merged.
