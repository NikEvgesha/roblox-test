# MVP Task Board

Last verified: `2026-07-20`

## Rules

- Statuses: `Backlog`, `In Progress`, `Blocked`, `Done`.
- `Assistant` means Codex implementation.
- `You` means Roblox/visual/account work performed by the project owner.
- `Shared` means a design, balance, or playtest decision.
- `Done` requires implementation plus an appropriate build, Studio smoke test, or published-client test.

## Epic A - Lobby And Match Entry

| ID | Task | Owner | Status | Verification / Next Gate |
|---|---|---|---|---|
| A-1 | Lock lobby UX baseline | Assistant | Done | `Docs/GDD_V2.md` |
| A-2 | Lock solo/manual/filled-party start policy | Assistant | Done | `Docs/OPEN_QUESTIONS.md` |
| A-3 | Teleport Lobby to reserved Combat server | Assistant | Done | Published `Lobby -> Combat -> Lobby` test passed `2026-07-19` |
| A-4 | Place and polish lobby visuals | You | Backlog | Final scene pass after cube prototype |
| A-5 | Queue-pad host flow for 1-8 players | Assistant | Done | Host, join limit, difficulty, manual/auto start implemented |
| A-6 | Keep Lobby and Combat in one Experience | Shared | Done | GameId `9947791898`; Lobby is Start Place |

## Epic B - Wave Loop

| ID | Task | Owner | Status | Verification / Next Gate |
|---|---|---|---|---|
| B-1 | Define wave loop state machine | Assistant | Done | `Docs/GAMEPLAY_LOOP_SYSTEM_SPEC.md` |
| B-2 | Implement prep/active/intermission cycle | Assistant | Done | Combat starts without runtime errors |
| B-3 | Spawn boss every 10th wave | Assistant | Done | Config and wave director implemented |
| B-4 | Fixed run target | Shared | Done | Current run is 50 waves; prior 10-wave cube baseline remains verified |
| B-5 | Player-count and difficulty scaling for 1-8 | Assistant | Done | Party income/count and four difficulty tiers implemented |
| B-6 | Complete 10-wave end-to-end playtest | Shared | Done | Published Wave 10 victory and return to Lobby verified by owner |
| B-7 | Accelerate prototype wave spawning | Assistant | Done | Configurable `x10` spawn cadence enabled |
| B-8 | Add twenty-enemy progressive roster | Assistant | Done | One variant per Wave 1-5, then widening cadence through Wave 50; unlocked variants remain in later pools |
| B-9 | Add four rotating bosses with telegraphed abilities | Assistant | Done | One boss every 10 waves; all four spawn together on Wave 50 |
| B-10 | Configure high-density 50-wave curve | Assistant | Done | Medium solo scales 100 -> 500 mobs; cap 500; 8 spawn points at radius 150 |

## Epic C - Professions And Abilities

| ID | Task | Owner | Status | Verification / Next Gate |
|---|---|---|---|---|
| C-1 | Lock first profession roster | Assistant | Done | `Docs/GDD_V2.md` |
| C-2 | Define ability/resource model | Assistant | Done | `Docs/ABILITY_SYSTEM_SPEC.md` |
| C-3 | Profession selection and teleport loadout | Assistant | Done | Gunner/Guardian selection and run loadout implemented |
| C-4 | Gunner prototype kit | Assistant | Done | Mana, stance, passives, Piercing Shot, Grenade |
| C-5 | Guardian prototype kit | Assistant | Done | Rage, passives, Shield, Rage Heal, ultimate, test aura |
| C-6 | Final profession balance | Shared | Backlog | Starts after vertical slice is stable |
| C-7 | Endless Mastery infinite stat node | Assistant | Backlog | Design exists; runtime tree not implemented |

## Epic D - Economy, Death And Map Interaction

| ID | Task | Owner | Status | Verification / Next Gate |
|---|---|---|---|---|
| D-1 | Lock Soft/XP/Crystals economy | Assistant | Done | `Docs/GDD_V2.md` |
| D-2 | Temporary run shop and draft UI | Assistant | Done | Server purchases and draft shop UI implemented |
| D-3 | Place final shops, stations and risk zones | You | Backlog | After prototype map layout is selected |
| D-4 | One-time map upgrade interaction | Assistant | In Progress | Damage Shrine exists; generic station/risk framework remains |
| D-5 | Persistent crystals and lobby meta upgrade | Assistant | Done | Profile store and lobby upgrade flow implemented |
| D-6 | Solo/team Developer Product revive | Assistant | In Progress | Receipt flow exists; live purchase test pending |
| D-7 | Shared kill rewards and party bonus | Assistant | Done | Soft/XP split formula implemented |
| D-8 | Profession unlocks and achievements | Assistant | Backlog | Definitions and persistence model pending |
| D-9 | Centralize MarketplaceService receipts | Assistant | Done | `ReceiptRouter` is the sole `ProcessReceipt` owner; revive products register handlers |

## Epic E - UI, QA And Performance

| ID | Task | Owner | Status | Verification / Next Gate |
|---|---|---|---|---|
| E-1 | Maintain smoke/regression plan | Assistant | Done | `Docs/GAMEPLAY_LOOP_TEST_PLAN.md` |
| E-2 | Draft wave/shop/skills HUD | Assistant | Done | Prototype UI implemented |
| E-3 | Final UI visual pass | You | Backlog | Starts after UX stabilizes |
| E-4 | Run local smoke tests after milestones | Assistant | In Progress | Combat boots cleanly with the 50-wave configuration; full 50-wave run remains a manual gate |
| E-5 | Spectator/free-fly while dead | Assistant | Done | Camera and movement prototype verified manually |
| E-6 | Add automated Luau tests | Assistant | Done | 400 assertions across fifteen server/client suites |
| E-7 | Split oversized runtime scripts | Assistant | Done | Combat entrypoint is 173 lines; HUD state and weapon animation controllers extracted |
| E-8 | Remove unused enemy-pack overhead | Shared | Done | Legacy pack/examples removed; 24 retained templates moved to server-only storage |
| E-9 | Profile target combat wave | Shared | Done | Owner reports stable play at `500` active mobs; higher counts remain possible |
| E-10 | Add authorized mob load controls | Shared | Done | Studio and owner-only published buttons for `1/10/100` verified by owner |
| E-11 | Evaluate enemy animation direction | Shared | Done | Owner accepted procedural animation; temporary comparison assets were removed |
| E-12 | Review expanded enemy and boss visuals | You | Done | Owner accepted the 20-mob roster and four bosses for continued use |

## Epic F - Tooling And Release

| ID | Task | Owner | Status | Verification / Next Gate |
|---|---|---|---|---|
| F-1 | Two guarded Rojo mappings | Assistant | Done | Lobby `34872`, Combat `34873`, `servePlaceIds` configured |
| F-2 | Upgrade Rojo CLI and plugin to 7.7.0 | Shared | Done | Both servers use 7.7.0; Studio plugin updated |
| F-3 | Add repository working instructions | Assistant | Done | `AGENTS.md` and new-day workflow |
| F-4 | Add formatting, linting and analysis tools | Assistant | Backlog | StyLua, Selene, Luau LSP analysis |
| F-5 | Add repeatable build/start command | Assistant | Done | `scripts/start-dev.ps1` validates builds and both ports |
| F-6 | Publish both places and test production entry | You | Done | Published route verified `2026-07-19` |
