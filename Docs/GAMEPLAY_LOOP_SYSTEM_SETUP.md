# GAMEPLAY_LOOP_SYSTEM_SETUP

## Purpose

Describe runtime setup for a two-place structure (`Lobby Place` + `Combat Place`) in the current Rojo pipeline.

## Required Files (MVP)

- `src/server/main.server.lua`
- `src/server/boot.server.lua`
- `src/server/combat.server.lua`
- `src/server/zombies.server.lua`
- `src/server/skills.server.lua`
- `src/client/main.client.lua`
- `src/shared/Shared.lua`
- `src/shared/CombatConfig.lua`
- `default.project.json`

## Rojo Mapping

- `src/server` -> `ServerScriptService`
- `src/client` -> `StarterPlayer/StarterPlayerScripts`
- `src/shared` -> `ReplicatedStorage/Shared`

## Local Setup

1. `aftman install`
2. `rojo serve default.project.json`
3. In Studio (Rojo plugin), click `Connect` to `localhost:34872`
4. Verify Rojo-managed scripts are visible in Explorer

## Place Setup Checklist

1. Prepare 2 places in the same experience:
   - `Lobby Place`
   - `Combat Place`
2. Store both `placeId` values in server config (TBD: final config path).
3. Confirm teleport from lobby to combat and back is enabled.
4. Configure spawn zones and safe start points in both places.

## Runtime Wiring

1. `main.server.lua` starts core match/run services.
2. `combat.server.lua` controls run and intermission states.
3. `zombies.server.lua` handles wave spawn and enemy lifecycle.
4. `skills.server.lua` handles class selection and skill upgrades.
5. `main.client.lua` consumes run state, HUD, shop, and skill events.

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
