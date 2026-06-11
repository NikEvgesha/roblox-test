# Hybrid Source-of-Truth

## Active Design Documents

1. `GDD_V2.md` is the active human-readable game design.
2. `GPT_PROJECT_CONTEXT.md` is the compact context file for AI-assisted work.
3. `CUBE_PROTOTYPE_PLAN.md` is the active implementation plan for the cube prototype.
4. `ABILITY_SYSTEM_SPEC.md` is the active technical spec for professions/resources/abilities.
5. `GDD_MVP.md` is historical. If it conflicts with `GDD_V2.md`, use `GDD_V2.md`.

## Ownership Matrix

| Domain | Source of Truth | Storage |
|---|---|---|
| Luau scripts | Git | `src/*` |
| Config/docs/process | Git | repo files |
| Places/world/terrain/assets | Roblox cloud | Group-owned experience |
| Planning/priorities/status | Linear | Team board |

## Ground Rules

1. Do not treat `.rbxl/.rbxlx` exports as merge artifacts.
2. Keep code changes in Git with Rojo sync, not only in Studio.
3. Every world-only change must be written to `WORLD_CHANGELOG.md`.
4. Every change should reference a Linear issue key (for example `IGR-42`).
5. A task is done only when code/world + docs + issue status are all updated.
6. Script Sync is not used in this repository.
