# GAMEPLAY_LOOP_SYSTEM_SPEC

## Goal

Define the MVP gameplay loop contract for cooperative wave survival:

1. Players form a party in a separate `Lobby Place`.
2. Party teleports into `Combat Place`.
3. Team survives enemy waves with buy/upgrade windows.
4. Standard waves alternate with boss waves.
5. Run ends in victory or wipe, then returns to lobby.

## Scope (MVP)

- One core mode: wave survival.
- Server authoritative run and wave states.
- Basic economy: wave rewards, shop spending, risk zone bonus.
- In-run progression: levels, skill points, and gated ULT scaling.
- Starting classes: `Assault`, `Builder`, `Healer`, `Melee`.
- Solo start is allowed.
- Lobby staging supports up to `6` players.
- Run duration target: `20+ minutes`.
- Victory condition: clear fixed target wave count.

## Place Flow

| Phase | Place | Responsibility |
|---|---|---|
| `PartyForming` | Lobby Place | Grouping and ready check |
| `MatchLaunch` | Lobby Place -> Combat Place | Teleport party into combat server |
| `RunActive` | Combat Place | Waves, economy, progression, bosses |
| `RunEnd` | Combat Place -> Lobby Place | Final summary and return flow |

## Lobby Queue Rules (Locked Baseline)

- Queue uses lobby `Queue Pads`.
- First player entering a free pad becomes queue host.
- Host configures:
  - difficulty;
  - target party size (up to 6).
- Other players join host queue while slots are available.
- If queue is full, join request is rejected.
- Match starts when:
  - queue reaches target party size; or
  - host manually starts.

## Combat State Machine

| State | Owner | Entry | Exit | Timeout |
|---|---|---|---|---|
| `PreRun` | Server | Players loaded into combat | Start timer begins | 20s |
| `WavePrep` | Server | New wave preparation | Prep timer ends | 20-45s |
| `WaveActive` | Server | Wave enemies spawned | All enemies dead or full team wipe | 45-180s |
| `Intermission` | Server | Wave completed | Next wave selected/reached | 20-60s |
| `BossWaveActive` | Server | Boss checkpoint wave | Boss dead or full team wipe | 60-240s |
| `RunResult` | Server | Win/lose condition reached | Rewards and summary sent | 10s |
| `ReturnToLobby` | Server | `RunResult` finished | Teleport back confirmed | 30s |

Rule: invalid transitions are rejected and logged.

## Fixed Run Rules (Locked)

- `BOSS_WAVE_INTERVAL = 10`
- `SOLO_MATCH_ALLOWED = true`
- `RUN_WIN_MODE = fixed_wave_target`
- `TARGET_RUN_DURATION = 20+ min`
- `TARGET_WAVE_COUNT = 100 (current baseline, tunable upward)`
- `LOBBY_MAX_PLAYERS = 6`
- `DEATH_PENALTY_RUN_CURRENCY = none`
- `FREE_RESPAWN_TIMER_MODEL = 10s first death, +10s each next death`
- `PAID_SOLO_RESPAWN = 10 Robux (fixed)`
- `TEAMMATE_REVIVE_WHEN_ALL_DEAD = 50 Robux`
- `FULL_TEAM_WIPE_PURCHASE_WINDOW = 30s`

## Data Contract (MVP)

- Shared module: `src/shared/Shared.lua`
- Required event channels:
  - `MatchStateChanged`
  - `QueuePadEntered`
  - `QueuePadLeft`
  - `QueueHostAssigned`
  - `QueueConfigUpdated`
  - `QueueJoinRejected`
  - `QueueReady`
  - `DifficultySelected`
  - `WaveStateChanged`
  - `WaveNumberChanged`
  - `IntermissionTimerUpdated`
  - `RunResultPublished`
  - `ShopOpened`
  - `ClassSelected`
  - `PlayerLeveledUp`
  - `SkillPointGranted`
  - `SkillPointSpent`
  - `SkillUpgraded`
  - `PlayerDowned`
  - `RespawnTimerUpdated`
  - `PlayerRespawned`
  - `PaidSoloReviveRequested`
  - `PaidTeamReviveRequested`
  - `WipeWindowStarted`
  - `WipeWindowTick`
  - `RunCurrencyUpdated`
  - `KillRewardDistributed`
  - `BossCrystalAwarded`
  - `AchievementProgressUpdated`
  - `AchievementCompleted`
  - `CharacterUnlocked`
- All client payloads are server validated.

## Skill Progression Rules (Locked Baseline)

- Player gains XP during run and levels up.
- Each level-up grants exactly `1` skill point.
- Skill point spend options:
  - unlock new skill;
  - upgrade existing skill;
  - unlock class-specific weapon node (if defined in class tree);
  - upgrade universal stat node (`Endless Mastery`).
- ULT upgrade gate:
  - ULT upgrade node is only available on levels divisible by `6`.
  - On those levels, player can choose ULT upgrade or other spend options.
  - ULT spend is optional, never forced.
- Skill rank caps:
  - standard skill nodes cap at rank `20`;
  - universal `Endless Mastery` has no rank cap.
- XP and all in-run skill progression reset at run end.

## Economy Rules (MVP Draft)

- Run-local money sources (resets after run):
  - enemy kills;
  - wave completion;
  - risk zone bonus.
- Run-local money sinks:
  - weapon/gear purchases;
  - upgrade station spending;
  - consumables (optional for MVP).
- Run XP and run-local money are not persistent and are wiped at run end.
- Kill reward distribution (shared):
  - all active players receive reward share for each kill;
  - `N = active player count`;
  - if `N = 1`: bonus multiplier = `1.0`;
  - if `N > 1`: bonus multiplier = `1 + 0.10 * N`;
  - `moneyPerPlayer = baseMoney * bonusMultiplier / N`;
  - `xpPerPlayer = baseXP * bonusMultiplier / N`.
- Persistent currency model:
  - Boss waves drop `Crystals`.
  - `Crystals` persist between runs.
  - `Crystals` are spent on lobby-side permanent upgrades.
- Shop structure:
  - Shop inventory is static.
  - Shop locations are distributed across map; some are hidden.
- Difficulty model:
  - players choose difficulty before run start;
  - locked multipliers: `Easy x0.5`, `Medium x1`, `Hard x2`, `Insane x4`;
  - multipliers apply to enemy health, enemy damage, enemy count, run rewards, and boss crystal payout.
- Player-count scaling:
  - enemy count scales with party size bonus `+10% * N` (only if `N > 1`);
  - only `money` and `XP` use shared bonus split formula;
  - crystal payout is not party-bonus scaled.
- Lobby staging size:
  - up to 6 players per queue/match launch group.

## Meta Progression Rules (MVP Baseline)

- Character unlock paths:
  - crystal purchase in lobby;
  - achievement completion.
- Achievement state and unlocked characters persist between runs.

## Death / Respawn Rules (Locked Baseline)

- Run fails only when all players are dead simultaneously.
- Individual death has no run-money or XP penalty.
- Respawn flow:
  - free auto-respawn starts at `10s` on first death;
  - each next death adds `+10s` to free auto-respawn timer;
  - paid solo respawn is available for `10 Robux` (fixed);
  - if all players are dead, only paid respawns are allowed for `30s`:
    - `Solo Revive` (`10 Robux`) revives purchaser;
    - `Teammate Revive` (`50 Robux`) revives all downed players.
- While waiting for respawn, player can spectate/free-fly.

## Failure Modes

| Failure | Handling |
|---|---|
| Invalid transition | Reject and warn, keep previous state |
| Wave stall | Force wave end on timeout fallback |
| Reward grant error | Retry once, then log and continue |
| Mid-run disconnect | Remove from active team and rebalance |
| Return teleport failure | Retry until timeout, then kick with reason |

## Out of Scope (MVP)

- PvP and ranked systems.
- Deep account meta progression.
- Quest chains and story progression.
- Full crafting/base-building meta.
