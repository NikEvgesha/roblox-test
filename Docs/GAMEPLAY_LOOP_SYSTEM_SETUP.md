# GAMEPLAY_LOOP_SYSTEM_SETUP

## Purpose

Describe how gameplay loop code is wired between local files and Roblox Studio runtime.

## Required Files

- `src/server/main.server.lua`
- `src/server/boot.server.lua`
- `src/client/main.client.lua`
- `src/shared/Shared.lua`
- `default.project.json`

## Rojo Mapping

- `src/server` -> `ServerScriptService`
- `src/client` -> `StarterPlayer/StarterPlayerScripts`
- `src/shared` -> `ReplicatedStorage/Shared`

## Local Setup

1. `aftman install`
2. `rojo serve`
3. Connect Rojo plugin to `localhost:34872`
4. Verify server/client scripts appear in Explorer

## Studio Runtime Wiring

1. Keep Team Create enabled for world collaboration.
2. Do not edit Rojo-managed scripts directly in Studio.
3. World-only edits are allowed in Studio and must be logged in `Docs/WORLD_CHANGELOG.md`.

## Collaboration Rules

- One issue -> one branch -> one merge.
- No direct push to `master`.
- Every gameplay loop change references a Linear issue key in commit message.

## Validation Check

Pass when all are true:
1. Output shows server log from `main.server.lua`.
2. Output shows client log from `main.client.lua`.
3. Play session starts without script permission/sync errors.
