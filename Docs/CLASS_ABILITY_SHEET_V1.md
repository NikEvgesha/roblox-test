# CLASS_ABILITY_SHEET_V1

## Core Progression Model (Locked)

1. Player gains XP and levels up during run.
2. Each new level grants `1` skill point.
3. A point can be spent to:
   - unlock a new skill node;
   - upgrade an unlocked skill node;
   - unlock class-specific weapon node;
   - upgrade universal stat node (`Endless Mastery`).
4. ULT rule:
   - ULT upgrade is available only at levels divisible by `6`.
   - On level `6/12/18/...` player may choose ULT or another node.
   - ULT upgrades are optional.
5. All run XP and skill progression reset at run end.
6. Max rank per standard skill node is `20`.
7. Universal stat node (`Endless Mastery`) has no max rank.

## Clarification Example (Level 6)

- Player reached level 6 and has earned 5 spendable points through progression.
- At level 6, ULT node becomes eligible for upgrade.
- Player may:
  - spend point on ULT;
  - or spend point on another skill/weapon node.

## Class Node Draft (MVP)

## Universal Node (All Classes)

| Node | Type | Effect (Draft) |
|---|---|---|
| `Endless Mastery` | Passive (Infinite Rank) | Small all-stat increase per rank (damage/survivability/utility tuning) |

## Endless Mastery - Locked Stat Package v1

Primary stats per rank (low incremental values to support infinite scaling):

| Stat | Suggested Per Rank (Draft) | Notes |
|---|---|---|
| Move Speed | `+0.15%` | Keep low to avoid movement breakpoints |
| Attack Speed / Fire Rate | `+0.20%` | Strong DPS scaler, watch weapon-specific caps |
| Skill Cooldown Recovery | `+0.20%` | Implement via CDR model with hard cap |
| Max HP | `+0.30%` | Core survivability line |
| Damage | `+0.20%` | Global outgoing damage multiplier |
| Armor / Damage Reduction | `+0.10%` | Should use cap to prevent invulnerability |

Optional stats (enable later if needed):
- reload speed;
- stamina or dash resource;
- status resistance;

Note:
- Reload speed is deferred because reload may not exist globally and can remain class-specific.

## Assault

| Node | Type | Effect (Draft) |
|---|---|---|
| `Suppressive Burst` | Active | Short fire-rate boost with recoil increase |
| `Ammo Discipline` | Passive | Reduced reload time and spread bloom |
| `LMG Access` | Weapon Unlock | Unlock heavy automatic weapon tier |
| `Armor-Piercing Rounds` | ULT | Temporary damage bonus vs elites/bosses |

## Builder

| Node | Type | Effect (Draft) |
|---|---|---|
| `Deploy Barricade` | Active | Spawn short-life cover segment |
| `Auto Turret` | Active | Place low-DPS turret with limited ammo |
| `Efficient Construction` | Passive | Lower deploy cost and faster placement |
| `Fortified Structures` | ULT | Strong temporary durability boost for deployables |

## Healer

| Node | Type | Effect (Draft) |
|---|---|---|
| `Field Heal` | Active | Targeted burst heal on ally |
| `Medical Training` | Passive | Increased outgoing healing |
| `Recovery Beacon` | Active | Area heal-over-time zone |
| `Protection Field` | ULT | Team shield window with short duration |

## Melee

| Node | Type | Effect (Draft) |
|---|---|---|
| `Dash Strike` | Active | Gap close + cleave hit |
| `Iron Guard` | Passive | Damage reduction while close to enemies |
| `Concussion Slam` | Active | Short-range stun pulse |
| `Heavy Blade Mastery` | ULT | Temporary melee power spike and cleave width boost |

## Open Tuning Points

1. Exact per-rank scaling values are still open.
2. Weapon unlock node count per class is still open.
