# Rojo Setup (Required)

This repository uses Rojo as the only script sync pipeline.

## Prerequisites

1. Install `aftman` from the official releases.
2. Install the matching Rojo Studio plugin with `rojo plugin install`.
3. Make sure Roblox Studio is updated.

## CLI Setup

From repository root:

```powershell
aftman install
rojo --version
```

Expected result: `Rojo 7.7.0` is available in shell.

Install or refresh the matching local Studio plugin:

```powershell
rojo plugin install
```

If Studio still loads an older Marketplace copy, uninstall that copy from `Plugins -> Manage Plugins`, restart every Studio window, and keep the CLI-managed `RojoManagedPlugin.rbxm`.

## Studio Connection

1. Open your Group-owned place in Studio.
2. Start and verify both projects from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/start-dev.ps1
```

3. In Studio, open the Rojo plugin and connect to the matching port:
   - Lobby / Start Place `81561302455824` -> `34872`.
   - Combat `135533599453315` -> `34873`.
4. Confirm mapped trees appear in Explorer:
   - Lobby place:
     - `ServerScriptService` <- `src/lobby/server`
     - `StarterPlayer/StarterPlayerScripts` <- `src/lobby/client`
   - Combat place:
     - `ServerScriptService` <- `src/combat/server`
     - `StarterPlayer/StarterPlayerScripts` <- `src/combat/client`
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
