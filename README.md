# Heroic Survival

Roblox cooperative wave-survival project with separate Lobby and Combat places.

## Sources Of Truth

- Git: Luau code, Rojo mappings, configuration, documentation, and task status.
- Roblox cloud: world geometry, terrain, manually placed assets, and published places.
- `Docs/GDD_V2.md`: active human-readable design.
- `Docs/GPT_PROJECT_CONTEXT.md`: compact context for future Codex sessions.
- `Docs/MVP_TASK_BOARD.md` and `TODO.md`: current implementation status and priorities.

## Place Mapping

| Role | PlaceId | Rojo project | Port |
|---|---:|---|---:|
| Lobby / Start Place | `81561302455824` | `lobby.project.json` | `34872` |
| Combat | `135533599453315` | `combat.project.json` | `34873` |

Both places belong to Experience GameId `9947791898`.

## Repository Layout

- `src/lobby/server`: Lobby server scripts.
- `src/lobby/client`: Lobby client scripts.
- `src/combat/server`: Combat server scripts.
- `src/combat/client`: Combat client scripts.
- `src/shared`: modules mapped into both places.
- `Docs`: design, workflow, setup, and verification documents.
- `scripts/start-dev.ps1`: build check and idempotent Rojo startup.
- `AGENTS.md`: durable Codex workflow and ownership rules.

## Quick Start

```powershell
aftman install
rojo plugin install
powershell -ExecutionPolicy Bypass -File scripts/start-dev.ps1
```

Then connect Studio:

- Lobby to `localhost:34872`.
- Combat to `localhost:34873`.

The project files include `servePlaceIds`; do not bypass a PlaceId mismatch warning.

## Development Rules

1. Edit Rojo-managed scripts in `src`, not in Studio.
2. Use Studio for cloud-owned world and visual changes.
3. Build both projects after shared/config changes.
4. Smoke-test the affected Place and inspect Studio Output.
5. Test real teleports from a published Roblox client.
6. Update the task board when milestone status changes.

See `Docs/ROJO_SETUP.md` for detailed setup and `Docs/SOURCE_OF_TRUTH.md` for ownership boundaries.
