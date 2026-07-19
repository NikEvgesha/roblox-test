# GAMEPLAY_LOOP_SYSTEM_SETUP

## Purpose

Describe runtime setup for a two-place structure (`Lobby Place` + `Combat Place`) in the current Rojo pipeline.

## Required Files (MVP)

- `src/lobby/server/matchmaking.server.lua`
- `src/lobby/server/boot.server.lua`
- `src/lobby/client/main.client.lua`
- `src/combat/server/boot.server.lua`
- `src/combat/server/combat.server.lua`
- `src/combat/server/zombies.server.lua`
- `src/combat/server/skills.server.lua`
- `src/combat/client/main.client.lua`
- `src/shared/Shared.lua`
- `src/shared/CombatConfig.lua`
- `lobby.project.json`
- `combat.project.json`

## Rojo Mapping

- Lobby:
  - `src/lobby/server` -> `ServerScriptService`
  - `src/lobby/client` -> `StarterPlayer/StarterPlayerScripts`
- Combat:
  - `src/combat/server` -> `ServerScriptService`
  - `src/combat/client` -> `StarterPlayer/StarterPlayerScripts`
- `src/shared` -> `ReplicatedStorage/Shared`

## Local Setup

1. `aftman install`
2. `powershell -ExecutionPolicy Bypass -File scripts/start-dev.ps1`
3. In Studio (Rojo plugin), connect lobby place to `localhost:34872`
4. In Studio (Rojo plugin), connect combat place to `localhost:34873`
5. Verify Rojo-managed scripts are visible in Explorer

## Place Setup Checklist

1. Prepare 2 places in the same experience:
   - `Lobby Place`
   - `Combat Place`
2. Keep both Place IDs in `src/shared/CombatConfig.lua`.
3. Confirm teleport from lobby to combat and back is enabled.
4. Configure spawn zones and safe start points in both places.

## Runtime Wiring

1. Lobby server scripts handle queue/session entry and pre-run UX.
2. Combat server scripts handle wave director, combat loop, and respawn flow.
3. Shared modules are reused across both places via `ReplicatedStorage/Shared`.
4. Lobby client script stays lightweight (menu/queue hooks).
5. Combat client script handles HUD, shop, skills, and revive purchase UI.

## Collaboration Rules

- One task -> one branch -> one merge.
- No direct pushes to `main`.
- Any gameplay behavior change must update docs in `Docs`.

## Validation Check

Pass when all are true:
1. Server starts with no runtime error.
2. Client loads with no UI/Remote runtime error.
3. At least one full cycle runs: `WavePrep -> WaveActive -> Intermission`.
4. Rojo reconnect does not break active gameplay.
