# GAMEPLAY_LOOP_TEST_PLAN

## Test Goal

Validate that the wave survival loop remains stable after each task and does not break lobby/combat/return flow.

## Smoke Tests (every task)

| ID | Check | Steps | Expected |
|---|---|---|---|
| SMK-1 | Lobby startup | Join Lobby Place | Player spawns, lobby UI works |
| SMK-2 | Queue pad flow | Players enter same queue pad | Host config works, join limit enforced |
| SMK-3 | Lobby -> Combat teleport | Start run from lobby | Party arrives in Combat Place |
| SMK-4 | Shared kill rewards | Kill one enemy in party | All players receive split reward with group bonus |
| SMK-5 | Wave loop | Complete 2-3 waves | State order is prep -> active -> intermission |
| SMK-6 | Shop/intermission | Open shop between waves | Purchase succeeds and currency updates |
| SMK-7 | Boss wave | Reach boss checkpoint | Boss spawns and phase resolves correctly |
| SMK-8 | Run end | Team wipe or run win | Final summary appears and return to lobby triggers |
| SMK-9 | Death flow | Die during active wave | Free respawn timer starts at 10s and scales +10s per death |
| SMK-10 | Paid revive | Buy solo revive while downed | Immediate respawn succeeds after purchase |
| SMK-12 | Team wipe revive | Full team wipe, buy team revive in 30s | All downed players return, run continues |
| SMK-11 | Difficulty impact | Start runs on different difficulties | Enemy strength and rewards scale by selected tier |
| SMK-13 | Ghost enemy cleanup | Detach a living enemy Humanoid after all spawns finish | Invalid state is pruned and the wave resolves |
| SMK-14 | Authorized mob load controls | Click `Spawn 1`, `Spawn 10`, and `Spawn 100` in Combat Studio or as an authorized published user | Requested moving enemies spawn; tester remains alive; unauthorized users have no panel |
| SMK-15 | Gunner unlimited ammunition | Fire ranged weapons continuously and press `R` | Shots do not stop, no ammo HUD appears, and reload does not run |

## Automated Studio Tests

- Combat Studio runs eleven automated suites: five server services plus spectator, weapon, input, aim, HUD view, and feedback.
- Passing state: all corresponding `Workspace.*TestsPassed` attributes are `true`.
- `GameRulesTests`: `26` assertions for party rewards, XP progression, difficulty/stat scaling, respawn timing, meta costs, and ability upgrades.
- `WaveDirectorTests`: `19` assertions for wave lookup, boss cadence, spawn budgets, party/difficulty scaling, alive caps, spawn intervals, and variant weights.
- `EnemyRuntimeTests`: `18` assertions for registration, alive-state pruning, cleanup, nearest-target lookup, spawn-point safety, iteration, and full clear.
- `EnemyFactoryTests`: `41` assertions for fallback/template construction, scaling, state fields, health UI, callbacks, boss data, and animation cleanup.
- `ReviveRuntimeTests`: `47` assertions for death tokens, escalating free timers, markers, stale-timer rejection, teammate revive, wipe policy, team grant, timeout, and run cleanup.
- `SpectatorControllerTests`: `22` assertions for downed transitions, RMB-look cursor state, view-relative movement, and gameplay-camera restoration.
- `WeaponControllerTests`: `31` assertions for held fire, cadence multipliers, reload state, ranged dispatch, melee dispatch, and blocking states.
- `CombatInputControllerTests`: `25` assertions for LMB/RMB routing, shop/skills shortcuts, reload, blocking UI, and spectator forwarding.
- `AimControllerTests`: `26` assertions for aim state, strict crosshair visibility, nearest-target filtering, auto-lock, UnitRay/raycast fallback, cursor state, and blocking transitions.
- `CombatHudViewTests`: `19` assertions for required hierarchy, default visibility, list layouts, health/XP elements, and magazine/unlimited-ammo layouts.
- `CombatFeedbackControllerTests`: `18` assertions for hit routing, marker colors/lifetime, damage-number projection/text/lifetime, invalid payloads, and cleanup.
- Play Mode baseline: Medium solo Wave 1 reports budget `8`, alive cap `14`, spawn interval `0.29`, and creates `8` enemies.
- Factory baseline: every Wave 1 enemy has a root, Humanoid, and health bar; killing all enemies advances to `Intermission`.
- Revive baseline: solo death creates one downed marker and changes `WaveState` to `WipeWindow`; a fresh Combat boot reports all eleven suites passing.
- Spectator integration baseline: a `respawn` event switches to `Scriptable` camera and shows status; `respawn_clear` restores `Custom` camera with the local `Humanoid` as subject.
- Aim integration baseline: equipped R15 ranged combat creates and enables `RangedRightArmIK` with target/pole parts; spectator mode disables IK and crosshair, and revive restores the gameplay camera and crosshair.
- UI integration baseline: shop payload updates money/status and obeys distance auto-close; skills payload opens with current points; combat feedback creates marker and projected damage text.
- Ghost-state baseline: destroying one live enemy root and killing the remaining wave enemies produces `AliveZombies == 0` and advances to `Intermission`.

## Regression Matrix

| Area | Risk | Check |
|---|---|---|
| State machine | Invalid transitions | Force edge case and verify reject + log |
| Teleport | Party split/lost players | Verify full party travels together |
| Economy | Money/purchase dupes | Validate double-click and race-condition paths |
| Reward split | Wrong per-player payouts | Validate formula for solo and 8-player groups |
| Waves | Wave stall | Validate timeout fallback resolves |
| Classes/skills | Invalid unlock path | Validate level-based unlock/upgrade logic |
| Death/respawn | Stuck dead state | Validate free timer, solo revive, and wipe team-revive all resolve |
| Difficulty | Broken multipliers | Validate higher tier gives stronger mobs and higher rewards |

## Manual Test Scripts (MVP)

1. `TS-01 Solo run`: 1 player, 3-5 waves, baseline loop.
2. `TS-02 Squad run`: 2-8 players, wave scaling check.
3. `TS-03 Disconnect`: one player leaves mid-wave.
4. `TS-04 Death economy`: player death with no run-currency penalty.

## Execution Policy

- Run smoke tests before moving issue to `In Review`.
- Log result in issue/TODO with date and commit hash.
- If mechanics or balance changes, update `Docs/GDD_V2.md`.

## Pass/Fail Criteria

- Pass: all smoke tests pass and no critical Output errors.
- Fail: at least one smoke test fails or run cannot resolve cleanly.

## Reporting

If failed:
1. Create bug issue.
2. Add reproduction steps.
3. Attach log/screenshot and commit hash.
