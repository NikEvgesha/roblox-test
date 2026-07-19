# Heroic Survival Repository Instructions

## Session Start

When the user says `начался новый день`, immediately:

1. Run `powershell -ExecutionPolicy Bypass -File scripts/start-dev.ps1`.
2. List connected Roblox Studio instances through Studio MCP.
3. Identify places by `game.PlaceId` and `game.GameId`, never by window title alone.
4. Leave Combat Studio active unless the next task specifically targets Lobby.

## Place Mapping

| Role | PlaceId | GameId | Rojo project | Port |
|---|---:|---:|---|---:|
| Lobby / Start Place | `81561302455824` | `9947791898` | `lobby.project.json` | `34872` |
| Combat | `135533599453315` | `9947791898` | `combat.project.json` | `34873` |

Never sync a project to a PlaceId outside its `servePlaceIds` list.

## Sources Of Truth

Read in this order when restoring context:

1. `Docs/GPT_PROJECT_CONTEXT.md`
2. `Docs/GDD_V2.md`
3. `Docs/CUBE_PROTOTYPE_PLAN.md`
4. `Docs/ABILITY_SYSTEM_SPEC.md`
5. `Docs/MVP_TASK_BOARD.md`
6. `TODO.md`

`Docs/GDD_MVP.md` is historical. Prefer `Docs/GDD_V2.md` on conflict.

## Editing Boundaries

- Edit Rojo-managed scripts in `src/`, not directly in Studio.
- Keep world geometry, terrain, and manually placed visual assets in Roblox cloud.
- Before changing a Studio DataModel, list Studios and set the intended one active.
- Do not publish places, spend Robux, delete cloud assets, or change account settings without the user.
- Do not remove Toolbox packs until the user identifies which visual assets to retain.

## Ownership

- Codex: gameplay code, infrastructure, draft UI, tests, documentation maintenance.
- User: final visuals, final map placement, final UI art, Creator Hub settings.
- Shared: balance, feel, profession kits, wave composition, achievements.

## Verification

- Build both projects after shared/config changes.
- Smoke-test the affected Place in Studio and inspect Output.
- Test real teleports only in a published Roblox client; Studio cannot complete production teleports.
- Update `Docs/MVP_TASK_BOARD.md` or `TODO.md` when milestone status changes.

