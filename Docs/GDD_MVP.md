# GDD_MVP

## Vision

Cooperative survival shooter in Roblox:
- players gather in lobby;
- form a party;
- enter a combat run with enemy waves;
- power up during the run (levels, skills, gear);
- survive standard and boss waves.

## Core Pillars

1. `Co-op first`: group play should be stronger than solo.
2. `Pressure loop`: each wave increases threat and forces adaptation.
3. `Build choice`: between waves, player choices change playstyle.
4. `Readable chaos`: high enemy count, but player can read threats.

## Session Flow

1. Players join `Lobby Place`.
2. Party forms and starts run.
3. Party enters `Combat Place`.
4. Wave cycle:
   - preparation;
   - active wave;
   - intermission (shop/upgrades).
5. Boss waves appear at checkpoints.
6. Run ends by fixed wave target completion (`100` baseline, tunable upward) or team wipe.
7. Return to lobby.

Session target: `20+ minutes`.
Solo start: `allowed`.
Lobby capacity per match staging: up to `6` players.

## Match Setup (Pre-Run)

- Before run start, players choose `Difficulty`.
- Party assembly uses `Queue Pads` in lobby:
  - first player entering a pad becomes host;
  - host sets difficulty and target party size;
  - next players join host queue until capacity is reached;
  - if queue is full, new players cannot join that queue.
- Run launch conditions:
  - auto start when queue reaches target party size;
  - or manual start by host before full queue.
- Difficulty affects:
  - enemy strength;
  - enemy count pressure (together with player-count scaling);
  - reward output (`run money`, `run XP`, boss `Crystals`).
- Locked baseline multipliers:
  - `Easy x0.5`
  - `Medium x1`
  - `Hard x2`
  - `Insane x4`

## Map Design (MVP)

- `Safe Hub`: initial safe area.
- `Shops`: static weapon/gear purchase points distributed across the map.
- `Upgrade Stations`: class/stat upgrade points.
- `Risk Zones`: harder zones with higher rewards.
- Some shops are intentionally hidden to reward map knowledge.

MVP rule: map should support a 20+ minute long-form run.

## Class Set (MVP)

| Class | Role | Base Focus |
|---|---|---|
| `Assault` | DPS | stable crowd damage |
| `Builder` | Utility/Control | turret, barricade, area control |
| `Healer` | Sustain/Support | healing and survival support |
| `Melee` | Frontline | aggro and close-range control |

## Progression (In-Run)

- All players start at `level 1`.
- XP from kills, wave clears, and events.
- Each level-up grants `1` skill point.
- A point can be spent to:
  - unlock a new ability;
  - upgrade an already unlocked ability;
  - unlock class-specific weapon access (where applicable);
  - upgrade universal stat node (`Endless Mastery`).
- Ultimate ability (`ULT`) has gated upgrade access:
  - ULT upgrade is available on levels divisible by 6 (`6`, `12`, `18`, ...).
  - Player is not forced to spend point on ULT at those levels.
  - Player may still spend point on non-ULT options instead.
- Maximum rank per regular skill node: `20`.
- Universal stat node (`Endless Mastery`) is available to all classes and has no max rank.
- `Endless Mastery` stat package includes:
  - move speed;
  - attack speed / fire rate;
  - cooldown recovery;
  - max HP;
  - damage;
  - armor;
  - crit chance;
  - crit damage;
  - HP regen;
  - lifesteal.
- Reload-speed scaling is deferred. Reload may be omitted globally and later tied only to specific class kits if needed.
- Run XP is temporary and resets after run end.

## Death / Respawn Loop

- Team loses run only when all players are dead at the same time.
- No run-money or XP penalty on individual death.
- Respawn options:
  - free auto-respawn starts at `10s`;
  - each next death adds `+10s` to free timer;
  - paid solo revive is `10 Robux` (fixed).
- If all players are dead:
  - only paid revive is allowed for `30s`;
  - `Solo Revive` (`10 Robux`) revives purchaser;
  - `Team Revive` (`50 Robux`) revives all downed players.
- During respawn timer, dead player can spectate and free-fly across map.

## Economy (MVP)

Run-local income (temporary):
- kills;
- wave completion;
- risk zone activity.
- Kill reward sharing:
  - all active players receive shared XP/money from each kill;
  - reward is split with group bonus.

Run-local spending:
- weapons;
- upgrades;
- consumables (optional for MVP).

Persistent progression currency:
- `Crystals` drop from boss waves.
- Crystals are kept after run and spent in lobby upgrades.

## Reward Share Formula (Kill Rewards)

For party size `N`:
- if `N = 1`: no group bonus.
- if `N > 1`: bonus multiplier is `1 + 0.10 * N`.

Per-player reward:
- `moneyPerPlayer = baseMoney * bonusMultiplier / N`
- `xpPerPlayer = baseXP * bonusMultiplier / N`

Example for `N = 6`, base kill reward `6 money` and `60 XP`:
- multiplier = `1.6`
- each player gets `6*1.6/6 = 1.6 money`
- each player gets `60*1.6/6 = 16 XP`

## Boss Waves (Draft)

- Every `10th` wave is a boss wave.
- Boss patterns should encourage class cooperation.
- Boss reward should exceed standard wave reward.
- Bosses are the primary source of persistent `Crystals`.

## MVP Success Criteria

MVP is successful if:
1. Run victory target is configured to `100` waves (tunable upward later).
2. The 4 starting classes feel meaningfully different.
3. At least one full loop works: `lobby -> combat -> lobby`.
4. Test session with 1-6 players runs 20+ minutes without critical soft locks.

## Core Loops

1. Session loop:
   - players gather in lobby and form queue;
   - choose difficulty and launch run;
   - clear waves and bosses, collect run resources and crystals;
   - return to lobby;
   - spend crystals on upgrades/new characters;
   - queue again for harder run.

2. In-run combat loop:
   - kill enemies;
   - gain shared money and XP;
   - spend money on gear and upgrades;
   - become stronger and push deeper waves;
   - repeat until win or team wipe.

3. Meta loop:
   - keep crystals after run;
   - buy lobby upgrades and unlock characters;
   - some characters unlock via achievements instead of purchase.

## Character Unlock Rules (MVP Baseline)

- Character acquisition paths:
  - buy with persistent `Crystals`;
  - unlock by completing specific achievements.
- Achievement-driven character unlocks are part of planned MVP scope.

## Non-MVP

- Deep account meta progression.
- PvP modes.
- Large class catalog and complex talent trees.
