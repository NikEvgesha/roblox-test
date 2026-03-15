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
