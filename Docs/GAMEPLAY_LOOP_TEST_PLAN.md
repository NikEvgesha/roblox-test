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
| SMK-14 | Studio mob load controls | Click `Spawn 1`, `Spawn 10`, and `Spawn 100` in Combat Studio | Requested moving enemies spawn; tester remains alive; no runtime errors |
| SMK-15 | Gunner unlimited ammunition | Fire ranged weapons continuously and press `R` | Shots do not stop, no ammo HUD appears, and reload does not run |

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
