# Rojo Setup (Required)

This repository uses Rojo as the only script sync pipeline.

## Prerequisites

1. Install `aftman` from the official releases.
2. Install the Rojo Studio plugin from the official releases page.
3. Make sure Roblox Studio is updated.

## CLI Setup

From repository root:

```powershell
aftman install
rojo --version
```

Expected result: Rojo v7 is available in shell.

## Studio Connection

1. Open your Group-owned place in Studio.
2. Start the server from repository root:

```powershell
rojo serve
```

3. In Studio, open Rojo plugin and connect to `localhost:34872`.
4. Confirm mapped trees appear in Explorer:
   - `ServerScriptService` <- `src/server`
   - `StarterPlayer/StarterPlayerScripts` <- `src/client`
   - `ReplicatedStorage/Shared` <- `src/shared`

## Naming Rules

1. Server script files: `*.server.lua`
2. Client script files: `*.client.lua`
3. Module files: `*.lua`
4. Do not use `init.*` files directly in a root folder that is mapped to a fixed Roblox service.

## Team Rules

1. Edit Rojo-managed scripts in local files, not directly in Studio.
2. Keep `rojo serve` running while coding.
3. Use Team Create for world/assets only.
4. Record world-only changes in `Docs/WORLD_CHANGELOG.md`.
