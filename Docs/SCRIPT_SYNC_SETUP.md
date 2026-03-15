# Script Sync Setup

This project supports two sync modes. Start with Script Sync for fastest onboarding. Move to Rojo when the team is ready.

## Option A: Roblox Script Sync (recommended first)

1. In Roblox Studio: `File -> Beta Features` and enable Script Sync if requested by UI.
2. Open your Group-owned place.
3. Open script sync panel in Studio and map local folders:
   - `src/server` -> `ServerScriptService/Server`
   - `src/client` -> `StarterPlayer/StarterPlayerScripts/Client`
   - `src/shared` -> `ReplicatedStorage/Shared`
4. Save mapping.
5. Make a local edit in `src/server/init.server.luau` and verify Studio updates.

## Option B: Rojo (recommended for mature workflow)

1. Install Aftman and Rojo.
2. Use `default.project.json` from repo root.
3. Run:

```powershell
rojo serve
```

4. In Studio, connect Rojo plugin to `localhost:34872`.
5. Verify that `src/*` appears in DataModel per mapping.

## Team Rule

Pick one sync mode for all 3 developers and keep it consistent.
