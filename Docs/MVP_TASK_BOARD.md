# MVP_TASK_BOARD

## Rules

- Statuses: `Backlog`, `In Progress`, `Blocked`, `Done`.
- `Owner` values:
  - `Assistant` - implemented by Codex.
  - `You` - implemented by you in Studio.
  - `Shared` - pair decision/work.
- On task completion: add commit reference and short verification note.

## Epic A - Lobby & Match Entry

| ID | Task | Owner | Status | Output |
|---|---|---|---|---|
| A-1 | Lock lobby UX baseline (ready/start flow) | Assistant | Done | `Docs/GDD_MVP.md` |
| A-2 | Lock match start policy (solo allowed + fixed wave run mode) | Assistant | Done | `Docs/OPEN_QUESTIONS.md` |
| A-3 | Implement teleport Lobby -> Combat | Assistant | Backlog | Server teleport flow |
| A-4 | Place and polish lobby visuals | You | Backlog | Lobby scene pass |
| A-5 | Implement queue-pad host flow (host config, join limits, auto/manual start) | Assistant | Backlog | Lobby matchmaking queue logic |

## Epic B - Wave Loop

| ID | Task | Owner | Status | Output |
|---|---|---|---|---|
| B-1 | Define wave loop state machine spec | Assistant | Done | `Docs/GAMEPLAY_LOOP_SYSTEM_SPEC.md` |
| B-2 | Implement baseline wave prep/active/intermission cycle | Assistant | Backlog | `src/combat/server/combat.server.lua` |
| B-3 | Configure boss waves every 10th checkpoint | Assistant | Backlog | `src/combat/server/zombies.server.lua` |
| B-4 | Lock exact fixed wave target for run victory | Shared | Done | `100` baseline (tunable) |
| B-5 | Implement player-count scaling (1..6) + difficulty modifiers | Assistant | Backlog | Wave director scaling rules |

## Epic C - Classes & Skills

| ID | Task | Owner | Status | Output |
|---|---|---|---|---|
| C-1 | Lock MVP class roster and roles | Assistant | Done | `Docs/GDD_MVP.md` |
| C-2 | Define class ability sheet v1 (level points + optional ULT every 6 levels) | Assistant | Done | `Docs/CLASS_ABILITY_SHEET_V1.md` |
| C-3 | Implement class selection and effect application | Assistant | Backlog | `src/combat/server/skills.server.lua` + client UI |
| C-4 | Final class balance pass (damage/heal/cooldowns) | Shared | Backlog | Balance table |
| C-5 | Implement universal infinite stat node (`Endless Mastery`) | Assistant | Backlog | Skill tree + runtime stat scaling |

## Epic D - Economy & Map Interaction

| ID | Task | Owner | Status | Output |
|---|---|---|---|---|
| D-1 | Lock economy loop (income/spend) | Assistant | Done | `Docs/GDD_MVP.md` |
| D-2 | Implement intermission shop flow (server + draft UI) | Assistant | Backlog | Static distributed shop system |
| D-3 | Place upgrade stations and risk zones in map | You | Backlog | Map interaction points |
| D-4 | Wire station/risk gameplay scripts to placed map points | Assistant | Backlog | Interaction scripts |
| D-5 | Implement persistent boss crystal drops + lobby upgrade spend | Assistant | Backlog | Meta currency pipeline |
| D-6 | Implement paid revive flow (Solo 10R$ / Team 50R$ on wipe) | Assistant | Backlog | Respawn economy flow |
| D-7 | Implement shared kill-reward distribution with group bonus split | Assistant | Backlog | Reward distributor service |
| D-8 | Implement character unlocks (Crystal shop + achievement unlocks) | Assistant | Backlog | Character progression unlock service |

## Epic E - UI/QA/Playtest

| ID | Task | Owner | Status | Output |
|---|---|---|---|---|
| E-1 | Update smoke/regression test plan | Assistant | Done | `Docs/GAMEPLAY_LOOP_TEST_PLAN.md` |
| E-2 | Build draft HUD for waves/shop/skills | Assistant | Backlog | Temporary playable HUD |
| E-3 | Build final UI visual pass | You | Backlog | Final UI |
| E-4 | Execute `TS-01..TS-04` after each milestone | Shared | Backlog | Test notes |
| E-5 | Add spectate/free-fly flow while dead | Assistant | Backlog | Death spectator UX |
