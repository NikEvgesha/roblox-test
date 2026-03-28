# OPEN_QUESTIONS

## Resolved Decisions (2026-03-27)

1. Target run length: `20+ minutes`.
2. Win condition type: `fixed wave count`.
3. Solo match start: `allowed`.
4. Boss frequency: `every 10th wave`.
5. Class start ability count: `1` ability at start.
6. Progression model: level-based skill points (unlock/upgrade/weapon nodes).
7. Ownership split:
   - You: visual direction, environment placement, final UI.
   - Assistant: most systems code, specs, task tracking.
   - Balance: shared ownership.
8. Current run wave baseline: `100` waves (may be increased later).
9. Shop model: static inventories, distributed across map, with hidden shop points.
10. Progression persistence:
    - Run money and run XP are temporary and reset after run.
    - Boss `Crystals` are persistent and used for lobby upgrades.
11. Skill progression model:
    - each level grants `1` skill point;
    - point is spent on unlock/upgrade/weapon node;
    - ULT upgrade access opens every 6 levels (`6/12/18/...`), but spend is optional.
12. Skill rank policy:
    - standard skill node max rank = `20`;
    - universal stat node (`Endless Mastery`) is infinite rank.
13. Match scale and difficulty:
    - lobby supports up to `6` players;
    - difficulty is selected before run;
    - locked difficulty multipliers: `Easy x0.5`, `Medium x1`, `Hard x2`, `Insane x4`.
14. Death/respawn policy:
    - no run-money or XP penalty on death;
    - first free auto-respawn is `10s`;
    - each next death adds `+10s` to free auto-respawn timer;
    - paid solo revive is `10 Robux` (fixed);
    - if all players die, wipe window is `30s`;
    - during wipe window, players can buy:
      - solo revive (`10 Robux`);
      - team revive (`50 Robux`);
    - run fails only if all players die.
15. Party scaling policy:
    - bonus split formula (`1 + 0.10 * N`, then divide by `N`) applies to `money` and `XP` only;
    - enemy count also scales with `+10% * N` (only when `N > 1`);
    - crystal payout is not party-bonus scaled.
16. Teammate revive option on full wipe: `enabled` with fixed `50 Robux`.
17. Endless Mastery stat package includes:
    - move speed;
    - attack speed/fire rate;
    - cooldown recovery;
    - max HP;
    - damage;
    - armor;
    - crit chance;
    - crit damage;
    - HP regen;
    - lifesteal.
18. Kill rewards are shared for all active players with group bonus multiplier:
    - if solo: no bonus;
    - if group: `1 + 0.10 * playerCount` before split.
19. Shared-income policy is limited to run `money` and `XP`.

## Still Open

## Q1 - Wave Scaling

1. Should enemy count scale with player count only, or also with player levels?
2. Do we need a hard cap for alive enemies at the same time?
3. What are target scaling multipliers for party sizes 1..6?

## Q2 - Difficulty / Rewards

1. Keep `Insane` permanently visible or unlock only after hard clear?

## Q3 - Respawn Economy

1. Should paid solo revive stay available while at least one teammate is alive, or only on wipe?

## Q4 - Class Details

1. For `Builder`: turret, barricade, or both in MVP?
2. For `Healer`: burst heal, heal-over-time, shield, or combination?
3. For `Melee`: block, dash, stun, or combo in MVP?
4. Exact per-rank values for Endless Mastery stats.

## Q5 - Character Unlocks / Achievements

1. Which characters are crystal-only vs achievement-only?
2. What are first 3-5 achievement definitions for MVP?
