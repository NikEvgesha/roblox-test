# Linear Seed Issues (IGR)

Use these as initial issues/epics for the Roblox project.

## Epic 1: Core Gameplay Loop

1. `Define game loop spec (spawn -> objective -> reward -> repeat)`
2. `Implement server round state machine`
3. `Implement client HUD for round state`
4. `Implement reward distribution and basic progression`
5. `Add fail-safe reset for broken round state`

## Epic 2: Networking and Data

1. `Create RemoteEvent/RemoteFunction contract document`
2. `Add shared validation layer for remote payloads`
3. `Implement server-side anti-exploit checks for core actions`
4. `Implement DataStore profile load/save wrapper`
5. `Add retry and fallback behavior for DataStore failures`

## Epic 3: World and Content

1. `Build prototype map (playable graybox)`
2. `Set spawn points, checkpoints, and safe zones`
3. `Add interaction prompts and feedback`
4. `Add collision and traversal cleanup pass`
5. `Record all world edits in WORLD_CHANGELOG.md`

## Epic 4: UI and UX

1. `Create HUD wireframe and style guide`
2. `Implement health/currency/timer widgets`
3. `Implement onboarding popup sequence`
4. `Implement error/toast notification component`
5. `Add localization-ready string table`

## Epic 5: Quality and Release

1. `Add smoke checklist for every release candidate`
2. `Create regression matrix for critical systems`
3. `Add crash and error telemetry events`
4. `Create release checklist and rollback procedure`
5. `Define minimum playable quality gate`

## Suggested Labels

- `server`
- `client`
- `shared`
- `world`
- `ui`
- `infra`
- `bug`
- `qa`

## Suggested Priority Mapping

- `P0`: blocks playability or release
- `P1`: core feature for MVP
- `P2`: polish and non-blocking improvements
