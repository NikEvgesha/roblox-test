# GPT Project Context

## Назначение

Этот файл нужен для быстрых будущих сессий Codex/GPT. Он хранит короткое состояние проекта, ключевые правила дизайна и технические договоренности.

Если контекст разговора потерян, сначала читать:

1. `docs/GPT_PROJECT_CONTEXT.md`
2. `docs/GDD_V2.md`
3. `docs/CUBE_PROTOTYPE_PLAN.md`
4. `docs/SOURCE_OF_TRUTH.md`
5. `docs/ROJO_SETUP.md`

## Текущая Игра

Roblox кооперативный survival для `1-8` игроков.

Основной loop:

1. Lobby.
2. Выбор профессии.
3. Создание группы на `1-8`.
4. Combat place.
5. Волны врагов.
6. XP + soft currency внутри забега.
7. Босс каждые `10` волн.
8. Hard currency с боссов.
9. Возврат в lobby.
10. Постоянные улучшения и открытие профессий за hard currency.

## Главные Термины

| Термин | Значение |
|---|---|
| `Profession` | Класс игрока, определяет умения, ресурс и стиль боя |
| `Soft` | Временная валюта внутри забега |
| `XP` | Временный опыт внутри забега |
| `Hard` / `Crystals` | Постоянная валюта для лобби |
| `Passive` | Постоянно активное умение |
| `Active` | Умение по нажатию с cooldown |
| `Stance` | Переключаемый режим, влияющий на другие умения |
| `Aura` | Включаемый эффект, постоянно потребляющий ресурс |

## Непереговорные Правила Дизайна

1. Игра поддерживает `1-8` игроков.
2. Прототип сначала делается на кубах, визуал добавляется позже.
3. Визуал и финальный UI делает пользователь, код в основном делает Codex.
4. Все важные решения сначала фиксируются в docs.
5. Код меняется через Git + Rojo, не только в Studio.
6. Lobby и Combat являются разными плейсами одного experience.
7. Hard currency сохраняется после смерти.
8. Soft, XP и временные улучшения теряются после смерти или конца забега.
9. Босс появляется каждые `10` волн.
10. Базовый рост HP врагов: `+1%` за волну.

## Текущий Технический Контекст

Workspace:

```text
E:\GitFork\RobloxProject
```

Rojo:

```text
Rojo 7.7.0
Lobby  -> localhost:34872 -> lobby.project.json
Combat -> localhost:34873 -> combat.project.json
```

Основные папки:

```text
src/lobby/server
src/lobby/client
src/combat/server
src/combat/client
src/shared
```

Активные плейсы по последней проверке:

| Place | PlaceId | Назначение |
|---|---:|---|
| `RobloxProjectLobby` | `81561302455824` | Lobby (Start Place) |
| `RobloxProjectCombat` | `135533599453315` | Combat |

## Что Уже Есть В Коде

Фактически в проекте уже есть черновые системы:

- Lobby queue pads.
- Выбор класса через `LobbyQueueEvent`.
- Meta upgrades через `LobbyMetaEvent`.
- Combat weapon system.
- Ranged/melee бой.
- Shop draft.
- Skills draft.
- Enemy wave scripts.
- Boss/crystal-related config.
- Revive products config.
- Spectator/free-fly draft.
- Persistent profile store.
- Ability runtime for `Gunner` and `Guardian`: resources, stance, active abilities, passives, ranks, skill point spending.
- Gunner implemented: `Pistol/Rifle` stance, Rifle mana spend, `PiercingShot`, `Grenade`, pistol/rifle damage passives, fire rate passive.
- Guardian implemented: Rage gain/decay, `Shield`, `RageHeal`, `UndyingRage`, `TestAura` toggle/drain, damage reduction, melee damage, damage per Rage.
- Combat minimap draft: player-centered map with enemy red dots from `Workspace.Zombies`.
- First one-time map upgrade: `DamageShrine` in combat, costs soft money once per run and grants run-only melee/ranged damage levels.
- Debug all-weapons spawn is disabled; profession starter weapons and shop purchases now matter in prototype tests.
- Published `Lobby -> Combat -> Lobby` routing was verified in the Roblox client on `2026-07-19`.
- Wave completion prunes structurally invalid zombie states so detached Humanoids cannot leave `1 alive` forever.
- A full accelerated Combat Studio run on `2026-07-20` reached Wave 10 `Victory`: a rootless enemy injected on Wave 5 was pruned, the boss awarded `+5` Crystals and `+1` BossKills, and the result ended at `AliveZombies = 0`. Only the published-client victory teleport remains to verify.
- Wave spawn cadence uses `Zombies.WaveSpawnSpeedMultiplier = 10` for the current high-density prototype test.
- Mob load controls spawn `1`, `10`, or `100` moving Walker enemies and grant invisible damage protection. They are available in Studio and in published servers only to UserIds explicitly listed in `Debug.EnemySpawnerAuthorizedUserIds`.
- Gunner magazines and reload are disabled through `Ammo.MagazinesEnabled = false`; ranged shots still use profession resources where configured.
- Shared `GameRules` owns pure reward split, XP, scaling, respawn, meta cost, and ability-upgrade calculations used by runtime code.
- Combat Studio automatically runs `GameRulesTests`; the current suite covers 26 assertions and reports through `Workspace.GameRulesTestsPassed`.
- Server `WaveDirector` owns wave-table selection, boss detection, spawn budgets, alive caps, spawn cadence, and enemy variant weights.
- Combat Studio automatically runs `WaveDirectorTests`; the current suite covers 19 assertions and reports through `Workspace.WaveDirectorTestsPassed`.
- Server `EnemyRuntime` owns the enemy registry, alive-state validation, ghost-state pruning, nearest-target lookup, spawn-point selection, and active-enemy iteration.
- Combat Studio automatically runs `EnemyRuntimeTests`; the current suite covers 18 assertions and reports through `Workspace.EnemyRuntimeTestsPassed`.
- Server `EnemyFactory` owns template/fallback model construction, scaling, health bars, animation loading/cleanup, state assembly, and death lifecycle callbacks.
- Combat Studio automatically runs `EnemyFactoryTests`; the current suite covers 41 assertions and reports through `Workspace.EnemyFactoryTestsPassed`.
- Server `ReviveRuntime` owns player life/downed state, markers, free-respawn timers, wipe-window timing, teammate revive, paid grant policy, and character death wiring.
- Combat Studio automatically runs `ReviveRuntimeTests`; the current suite covers 47 assertions and reports through `Workspace.ReviveRuntimeTestsPassed`.
- Client `SpectatorController` owns downed/free-fly state, view-relative movement, RMB camera look, cursor policy, and gameplay-camera restoration.
- Combat Studio automatically runs `SpectatorControllerTests`; the current suite covers 22 assertions and reports through `Workspace.SpectatorControllerTestsPassed`.
- Client `WeaponController` owns held-fire cadence, fire-rate/reload state, ranged and melee dispatch, melee speed scaling, and reload requests.
- Client `CombatInputController` owns LMB/RMB and keyboard routing between gameplay, spectator, shop, skills, and reload actions.
- Combat Studio runs `WeaponControllerTests` (31 assertions) and `CombatInputControllerTests` (25 assertions).
- Client `AimController` owns mouse UnitRay/raycast aiming, RMB enemy lock, character facing, head pitch/yaw, right-arm IK, crosshair/cursor policy, and neutral recoil state.
- Combat Studio runs `AimControllerTests` with 26 assertions; the live R15 smoke test verifies active `RangedRightArmIK` target/pole and spectator disable/restore behavior.
- Client `CombatHudView` owns construction of the draft HUD, crosshair, revive controls, shop, and run-skills hierarchy.
- Client `CombatHudController` owns weapon/ammo display state, HP/XP, shop and run-skill payloads, revive UI, and character/stat bindings.
- Client `CombatFeedbackController` owns hit markers, optional hit-confirm audio, projected damage numbers, and their lifetimes.
- Client `WeaponAnimationController` owns animation-track caching plus ranged/melee playback timing.
- Combat Studio runs `CombatHudViewTests` (19), `CombatHudControllerTests` (34), `CombatFeedbackControllerTests` (18), and `WeaponAnimationControllerTests` (17 assertions).
- `ReceiptRouter` is the sole owner of `MarketplaceService.ProcessReceipt`; revive products register handlers instead of replacing the callback.

Важно: часть docs и task board устарели. Актуальный дизайн теперь в `GDD_V2.md`.

## Ближайший Правильный План

1. Проверить опубликованный teleport `Lobby -> Combat` через Roblox-клиент.
2. Пройти полный кубовый забег на `10` волн и проверить возврат в Lobby.
3. Добавить автоматические проверки чистой игровой логики.
4. Разделить крупные runtime-скрипты на тестируемые сервисы.
5. Довести минимальный вертикальный срез:
   - lobby group;
   - profession select;
   - teleport;
   - waves;
   - 2 professions;
   - 4 ability types;
	- soft/XP/hard;
	- boss every 10 waves;
	- return to lobby.

## Зафиксированные Решения Для Кубового Прототипа

1. Первый тестовый забег: `10` волн.
2. `Wave 10` является boss wave.
3. После убийства босса игроки получают hard currency и возвращаются в lobby через результат забега.
4. Первый режим: фиксированный `Normal`; сложности добавляются позже.
5. Смерть: умерший игрок становится spectator/free-fly; если умерли все игроки, run failed; revive/robux пока не входят.
6. Reward split: `totalReward = baseReward * (1 + 0.10 * playerCount)`, затем делится на `playerCount`.
7. Первый boss дает `5 Crystals` каждому игроку.
8. Первый meta upgrade стоит `5 Crystals` и дает `+2% damage` навсегда.

## First Prototype Professions

`Gunner`:

- resource: `Mana`;
- `Max Mana = 100`;
- `Mana Regen = 10/sec`;
- stance переключает `Pistol` и `Rifle`;
- `Pistol` стреляет без расхода маны;
- `Rifle` тратит `3 Mana` за выстрел;
- патроны, магазины и перезарядка в текущем прототипе отключены;
- passives: pistol damage, rifle damage, fire rate;
- actives: `Piercing Shot`, `Grenade`;
- aura отсутствует.

`Guardian`:

- resource: `Rage`;
- `Max Rage = 100`;
- gains: `1 Rage / 20 dealt damage`, `1 Rage / 10 taken damage`;
- decay: `5/sec` after `5` seconds out of combat;
- passives: damage reduction, melee damage, damage per Rage;
- active: shield for `10% max HP`;
- active: spend all Rage to heal, more Rage gives stronger heal;
- ultimate: spend current Rage, become immortal for `5` seconds, can gain Rage during effect, cannot drop below `1 HP`;
- test aura: spends `5 Rage/sec`, gives nearby allies `+15% defense`.

Active skill numbers:

| Skill | Cost | Cooldown | Effect |
|---|---:|---:|---|
| `Piercing Shot` | 25 Mana | 8 sec | `2.5x weapon damage`, pierces up to `5` enemies |
| `Grenade` | 35 Mana | 12 sec | `120 damage`, `12 studs` radius, `0.8 sec` fuse |
| `Shield` | 20 Rage | 10 sec | shield equal to `10% max HP`, lasts `6 sec` |
| `Rage Heal` | all Rage | 15 sec | heals `0.6% max HP` per Rage; `100 Rage = 60% max HP` |
| `Undying Rage` | all Rage | 60 sec | immortal for `5 sec`, HP cannot end below `1` |

## First Prototype Enemies

| Enemy | HP | Speed | Damage |
|---|---:|---:|---:|
| `Normal` | 100 | 10 | 10 |
| `Fast` | 60 | 16 | 7 |
| `Tank` | 250 | 6 | 18 |
| `Boss` | 1500 | 7 | 25 |

Enemy HP scaling: `+1%` per wave.

## First Prototype Shop And Shrine

Soft shop sells temporary run upgrades:

| Upgrade | Cost |
|---|---:|
| damage | 100 Soft |
| max HP | 100 Soft |
| move speed | 80 Soft |
| resource regen / rage gain | 120 Soft |
| attack/fire rate | 150 Soft |
| cooldown recovery | 150 Soft |
| defense | 120 Soft |
| max MP/resource | 100 Soft |

One-time strong map upgrade: `Power Shrine`, using the same stat pool. Cost: `300 Soft`.

Minimap first version:

- square top-right UI;
- top-down arena view;
- no map rotation;
- players are blue dots;
- enemies are red dots;
- boss is a bigger red dot;
- shops/shrine icons can be added later.

## Что Не Делать Пока

1. Не тратить время на финальный визуал.
2. Не полировать UI сверх черновика.
3. Не строить сложный баланс до кубового прототипа.
4. Не вводить донат-профессии до понятного core loop.
5. Не добавлять много профессий, пока не проверены 2 первые.

## Открытые Решения Для Следующей Сессии

Mandatory design questions for the first cube vertical slice are closed. Add new questions as implementation exposes them.
