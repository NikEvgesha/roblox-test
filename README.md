# RobloxProject

Team Roblox project with hybrid source-of-truth:

- `Git` is source-of-truth for code, configs, docs, and process.
- `Roblox Studio cloud` is source-of-truth for world/scene/assets and published places.
- `Linear` is source-of-truth for planning, priorities, and task status.

## Repository Layout

- `src/server` -> server scripts
- `src/client` -> client scripts
- `src/shared` -> shared modules
- `Docs` -> workflow, setup, changelogs, and quality docs
- `default.project.json` -> Rojo mapping (optional but recommended)

## Quick Start

1. Open Roblox Studio and publish the place under Group ownership.
2. Keep Team Create/Collaborate enabled.
3. Edit Luau scripts from local files and sync through Script Sync or Rojo.
4. Log world-only changes in `Docs/WORLD_CHANGELOG.md`.
5. Track every task in Linear and link issue IDs in commits/changelog.

## Team Rules

1. One Linear issue per concrete task.
2. One branch per issue: `feat/IGR-123-short-name` or `fix/IGR-123-short-name`.
3. No direct pushes to `main`.
4. Close issue only after:
   - behavior verified in Studio,
   - docs/changelog updated,
   - code merged.
