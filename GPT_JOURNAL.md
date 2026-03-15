# GPT Journal (RobloxProject)

Start date: `2026-03-15`
Project path: `E:\GitFork\RobloxProject`

## Current Snapshot

- Team size: `3`
- Collaboration mode: `Roblox Team Create + Git + Linear`
- Main risk: world changes done in Studio without changelog/issue linkage

## Session Log

### 2026-03-15

- What changed:
  - initialized git repository;
  - created project folder structure (`src/server`, `src/client`, `src/shared`, `Docs`);
  - added base workflow docs and changelog templates;
  - added Rojo mapping scaffold and starter scripts.
- Why it matters:
  - team now has one documented process for code, world changes, and task tracking.
- What is next:
  - configure Rojo in each developer environment;
  - align Linear board with statuses/labels policy.
- Verification:
  - file structure created and visible in repository root.

### 2026-03-15 (Rojo-only migration)

- What changed:
  - migrated script file naming to Rojo conventions (`*.server.lua`, `*.client.lua`, `*.lua`);
  - switched docs/process from mixed sync to Rojo-only setup (`Docs/ROJO_SETUP.md`);
  - updated `default.project.json` mapping to direct service-level paths;
  - added `aftman.toml` to pin Rojo CLI version.
- Why it matters:
  - all developers now use one consistent code sync pipeline, reducing sync drift and merge mistakes.
- What is next:
  - each developer runs `aftman install` and validates `rojo serve` connection from Studio plugin.
- Verification:
  - repository contains renamed script files and updated setup docs.

### 2026-03-15 (Docs workflow completion)

- What changed:
  - added feature docs set:
    - `Docs/GAMEPLAY_LOOP_SYSTEM_SPEC.md`
    - `Docs/GAMEPLAY_LOOP_SYSTEM_SETUP.md`
    - `Docs/GAMEPLAY_LOOP_TEST_PLAN.md`
  - added process runbooks:
    - `Docs/TEAM_RULES.md`
    - `Docs/RELEASE_CHECKLIST.md`
  - synchronized `TODO.md` with active Linear queue (`IGR-5` to `IGR-9` top block);
  - updated `START_PROMPT.md`, `Docs/README.md`, and `Docs/LINEAR_WORKFLOW.md`.
- Why it matters:
  - required DocksForCodex structure is now present for first critical system;
  - daily cycle, quality gate, release, and conflict policies are explicitly documented.
- What is next:
  - move `IGR-5` to `In Progress` and complete onboarding verification for all 3 developers;
  - start implementation from `IGR-7` after onboarding closure.
- Verification:
  - docs index references new files;
  - TODO includes Linear-backed queue and quality/release/conflict gates.

### 2026-03-15 (Combat prototype: pistol + sword + ammo UI)

- What changed:
  - added server combat system in `src/server/combat.server.lua`:
    - tool loadout (`Pistol`, `Sword`),
    - shooting/reload/sword-hit actions via remotes,
    - ammo pickups spawned around players,
    - tracer + damage handling + weapon/pickup sounds.
  - added shared tuning config `src/shared/CombatConfig.lua`.
  - extended client HUD and input in `src/client/main.client.lua`:
    - ammo in mag/reserve display,
    - current equipped weapon label,
    - `LMB` for fire/swing and `R` for reload,
    - sword attack animation playback.
- Why it matters:
  - playable combat loop now exists for testing agent-driven feature delivery.
- Verification:
  - in Play test: ammo changed after shoot/reload (`12/36` -> `11/36` -> `12/35`);
  - tools visible in Backpack;
  - ammo pickups spawned near player (`Workspace.AmmoPickups` had active items).

### 2026-03-15 (Zombie PvE + XP/HP HUD)

- What changed:
  - added `src/server/zombies.server.lua`:
    - auto-creates `Workspace.ZombieSpawnPoints` (default points if empty),
    - spawns zombies on interval and keeps cap on alive count,
    - zombies chase nearest alive player and attack in close range,
    - zombie kill rewards (`Money` + `XP`) are granted to killer.
  - extended `src/server/combat.server.lua`:
    - gun/sword damage now tags humanoids with killer metadata (`creator`, `LastHitByUserId`, `LastHitAt`) for reliable reward attribution.
  - extended `src/server/main.server.lua`:
    - `leaderstats` now ensures `Money`, `XP`, and `Level` for each player.
  - extended `src/client/main.client.lua`:
    - added player HP bar HUD,
    - added XP progress bar with level display,
    - HUD updates from `Humanoid` health and `leaderstats` (`XP`/`Level`).
  - extended `src/shared/CombatConfig.lua`:
    - added shared `Progression` and `Zombies` tuning sections.
- Why it matters:
  - project now has a playable PvE loop (spawn -> combat -> rewards -> progression feedback).
- Verification:
  - `rojo build default.project.json` succeeded without script parse errors;
  - Studio MCP inspection confirmed runtime presence of `Workspace.ZombieSpawnPoints`, `Workspace.Zombies`, and zombie health BillboardGui instances.

### 2026-03-15 (Weapon shop + multi-weapon economy)

- What changed:
  - rebuilt combat config into unified catalog (`src/shared/CombatConfig.lua`) with:
    - six weapon entries: `Pistol`, `Rifle`, `Shotgun`, `Sniper`, `Bow`, `Bulava`,
    - per-weapon prices, fire/melee params, ammo pack prices/amounts,
    - per-weapon animation IDs and sound IDs.
  - rebuilt server combat pipeline (`src/server/combat.server.lua`):
    - supports all weapons instead of fixed pistol/sword,
    - supports ranged fire/reload and melee swing per equipped weapon,
    - preserves kill-credit tagging for zombie rewards.
  - added in-world weapon shop generation in server script:
    - creates `Workspace.Shops.WeaponShop`,
    - creates `Shopkeeper` NPC with proximity prompt,
    - opening prompt shows shop UI on client.
  - added full client shop UI (`src/client/main.client.lua`):
    - weapon list with buy buttons and ammo-purchase buttons,
    - refreshes after each purchase,
    - supports quick open with `B` key.
  - preserved player progression HUD (money, HP, XP) and noob dialogue.
- Why it matters:
  - players can now convert zombie-earned money into build progression (weapon unlocks and ammo sustain) through an in-world NPC store.
- Verification:
  - `rojo build default.project.json` completed successfully after the refactor.

### 2026-03-15 (Skill tree from level-ups)

- What changed:
  - added progression skill schema in `src/shared/CombatConfig.lua`:
    - skill set: `Speed`, `MeleeDamage`, `RangedDamage`, `Health`,
    - per-skill max levels and effect values.
  - added dedicated server skill system `src/server/skills.server.lua`:
    - created `Progression` folder per player (`SkillPoints`, skill levels),
    - upgrade validation and spending (`1 point = 1 skill level`),
    - applies derived stats to character (`WalkSpeed`, `MaxHealth`) on spawn and upgrades,
    - syncs skill state to client via `SkillEvent`.
  - updated XP leveling in `src/server/zombies.server.lua`:
    - every level-up now also grants `+1 SkillPoints`.
  - updated server combat in `src/server/combat.server.lua`:
    - melee/ranged damage now scales with corresponding skill levels.
  - expanded client HUD in `src/client/main.client.lua`:
    - added skill window UI with upgrade buttons and per-skill level display,
    - added skill indicator badge (arrow + available points counter),
    - opening via `K` hotkey and top HUD button.
- Why it matters:
  - level progression now directly translates into meaningful character growth and combat power choices.
- Verification:
  - `rojo build default.project.json` succeeds with the new scripts and refactors.

### 2026-03-15 (Advanced zombie archetypes + survival flow)

- What changed:
  - fully redesigned zombie server loop in `src/server/zombies.server.lua`:
    - added archetypes: `Walker`, `Crawler`, `Runner`, `Flyer`, `Spitter`, `Bomber`,
    - added time-based difficulty schedule with weighted archetype mixing,
    - added stage scaling for HP/damage/speed/rewards/spawn pressure.
  - implemented special zombie behaviors:
    - `Flyer` hovers while pathing,
    - `Spitter` launches projectile attacks,
    - `Bomber` detonates with area damage.
  - implemented survival match lifecycle:
    - player downed marker with teammate revive prompt,
    - 60-second auto-respawn window when at least one teammate is alive,
    - wipe detection (`all dead`) with game-over and delayed automatic restart.
  - added survival config fields in `src/shared/CombatConfig.lua` for:
    - archetype stats and visuals,
    - difficulty schedule and scaling,
    - wipe/respawn timing controls.
  - extended client HUD `src/client/main.client.lua`:
    - survival status banner,
    - downed auto-respawn countdown text from `SurvivalEvent`.
- Why it matters:
  - the zombie mode now has escalating threat variety and proper co-op fail/recover conditions instead of a single static enemy loop.
- Verification:
  - `rojo build default.project.json` completed successfully after integration.

### 2026-03-15 (Combat/aim/shop stability fixes)

- What changed:
  - updated ranged shooting in `src/server/combat.server.lua`:
    - tracer/fire origin now comes from weapon handle muzzle (instead of camera payload),
    - added auto-reload trigger when magazine reaches `0` and reserve is available.
  - improved melee hit reliability in `src/server/combat.server.lua`:
    - widened melee hit-center offset and switched to planar facing/range checks for close zombie targets.
  - fixed ammo pickup edge case in `src/server/combat.server.lua`:
    - pickups can now be collected even when no ranged weapon is currently owned (fallback to first ranged ammo pool).
  - hardened shop interaction in `src/server/combat.server.lua`:
    - server now rejects open/buy actions when player is too far from shop prompt.
  - improved client aiming and animation stability in `src/client/main.client.lua`:
    - RMB aim mode: lock center + hide cursor + center-screen shooting ray,
    - added center crosshair while aiming with ranged weapon,
    - replaced per-shot animation track creation with cached tracks (prevents 64-track overflow),
    - reload animation now also triggers on server-driven reload state.
  - added client shop auto-close in `src/client/main.client.lua`:
    - shop window closes automatically when player moves away from vendor.
  - adjusted zombie spawn grounding in `src/server/zombies.server.lua`:
    - spawn height now uses ground raycast + body size offsets to reduce floating and improve melee reach.
- Why it matters:
  - addresses key combat usability bugs: broken pistol animation, incorrect shot origin, stuck poses from animation overflow, unreliable melee contact, and shop UI desync by distance.
- Verification:
  - `rojo build default.project.json` completed successfully after these fixes.
