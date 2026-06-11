# Cube Prototype Plan

## Цель

Сделать рабочий прототип игры на простых кубах и базовых UI-элементах.

Критерий успеха: можно пройти минимальный loop `Lobby -> Combat -> Waves -> Boss -> Hard Currency -> Return Lobby -> Meta Upgrade` без финального визуала.

## Принципы

1. Кубы важнее красивых моделей.
2. Читаемость важнее атмосферы.
3. Все параметры должны быть легко настраиваемыми.
4. Каждый milestone должен запускаться и тестироваться в Studio.
5. Не делать большую систему, пока не проверен простой вертикальный срез.

## Milestone 0 - Техническая База

Статус: частично готово.

Нужно проверить и при необходимости поправить:

- Rojo `7.6.1`.
- Lobby serve на `34872`.
- Combat serve на `34873`.
- MCP подключение к обоим Studio.
- Build для `lobby.project.json`.
- Build для `combat.project.json`.

Done criteria:

- оба проекта билдятся;
- оба Rojo-сервера слушают порты;
- MCP выполняет Luau в обоих плейсах.

## Milestone 1 - Lobby Vertical Slice

Цель: игрок может создать группу и стартовать combat.

Системы:

- queue pads на `1-8` игроков;
- host определяется первым вошедшим;
- host выбирает target size;
- host нажимает `Start`;
- выбранная профессия сохраняется и передается в combat;
- teleport data содержит party, profession, difficulty или mode.

Кубовый визуал:

- pad = цветной прямоугольник;
- host marker = текст над pad;
- party size = простой BillboardGui или ScreenGui;
- start button = черновой UI.

Done criteria:

- solo старт работает;
- старт неполной группы работает;
- заполненная группа стартует автоматически или через host;
- выбранная профессия видна в combat.

## Milestone 2 - Combat Arena

Цель: игроки появляются в центре и видят понятную арену.

Карта:

- центр спавна игроков;
- 4-8 точек спавна врагов;
- простые стены или границы;
- 1 магазин;
- 1 точка одноразового сильного улучшения;
- minimap draft.

Кубовый визуал:

- игроки = стандартные персонажи;
- враги = цветные кубы;
- boss = большой куб;
- магазин = синий куб;
- одноразовое улучшение = желтый куб;
- enemy dots на карте = красные точки.

Minimap first version:

- square top-right UI;
- top-down arena view;
- no map rotation;
- players are blue dots;
- enemies are red dots;
- boss is a bigger red dot;
- shops/shrine icons can be added later.

Done criteria:

- игроки стартуют в центре;
- враги появляются снаружи;
- враги видны на карте;
- игрок может найти магазин и upgrade point.

## Milestone 3 - Wave Director

Цель: волны идут по понятному циклу.

Состояния:

```text
Countdown -> WaveActive -> WaveClear -> Intermission -> NextWave
```

Правила:

- перед первой волной есть countdown;
- враги бегут к ближайшему игроку;
- волна завершается после смерти всех врагов;
- каждая `10` волна является boss wave;
- HP врагов растет на `+1%` за волну;
- количество и max alive масштабируются от player count.

Done criteria:

- можно пройти минимум `10` волн;
- на 10 волне появляется босс;
- после убийства босса начисляется hard currency;
- wave UI показывает текущую волну и состояние.

## Milestone 4 - Professions And Abilities

Цель: проверить разные типы умений.

Для первого прототипа нужны минимум 2 профессии.

Решение: первыми делаем `Gunner` и `Guardian`.

| Профессия | Почему |
|---|---|
| `Gunner` | проще проверить дальний бой, passive, active, stance |
| `Guardian` | проще проверить ближний бой, rage, aura |

Минимум ability coverage:

| Ability Type | Пример |
|---|---|
| `Passive` | +урон или +скорость атаки |
| `Active` | выстрел/рывок/удар по области |
| `Stance` | режим одиночной цели vs режим толпы |
| `Aura` | включаемая зона урона или защиты с расходом ресурса |

Done criteria:

- игрок получает skill point за уровень;
- игрок может открыть или улучшить умение;
- умение реально меняет gameplay;
- UI показывает ресурс профессии.

### Gunner Prototype Kit

- `Max Mana = 100`.
- `Mana Regen = 10/sec`.
- `Stance`: `Pistol` / `Rifle`.
- `Pistol`: no mana cost.
- `Rifle`: `3 Mana` per shot.
- Passives: pistol damage, rifle damage, fire rate.
- Actives: `Piercing Shot`, `Grenade`.
- No aura in first prototype.

Active skill numbers:

| Skill | Cost | Cooldown | Effect |
|---|---:|---:|---|
| `Piercing Shot` | 25 Mana | 8 sec | `2.5x weapon damage`, pierces up to `5` enemies |
| `Grenade` | 35 Mana | 12 sec | `120 damage`, `12 studs` radius, `0.8 sec` fuse |

### Guardian Prototype Kit

- `Max Rage = 100`.
- `1 Rage / 20 dealt damage`.
- `1 Rage / 10 taken damage`.
- Rage decay: `5/sec` after `5` seconds out of combat.
- Passives: damage reduction, melee damage, damage per Rage.
- Active: shield for `10% max HP`.
- Active: spend all Rage to heal.
- Ultimate: spend current Rage, become immortal for `5` seconds, can gain Rage during effect, cannot drop below `1 HP`.
- Temporary test aura: spends `5 Rage/sec`, gives nearby allies `+15% defense`.

Active skill numbers:

| Skill | Cost | Cooldown | Effect |
|---|---:|---:|---|
| `Shield` | 20 Rage | 10 sec | shield equal to `10% max HP`, lasts `6 sec` |
| `Rage Heal` | all Rage | 15 sec | heals `0.6% max HP` per Rage; `100 Rage = 60% max HP` |
| `Undying Rage` | all Rage | 60 sec | immortal for `5 sec`, HP cannot end below `1` |

## Milestone 5 - Economy

Цель: разделить временную и постоянную экономику.

Soft:

- падает с врагов;
- тратится в combat;
- теряется после забега.

XP:

- падает с врагов;
- дает уровни;
- теряется после забега.

Hard:

- падает с boss waves;
- сохраняется после забега;
- тратится в lobby.

First prototype values:

- boss on wave `10` gives `5 Crystals` per player;
- first meta upgrade costs `5 Crystals`;
- first meta upgrade gives permanent `+2% damage`.

Done criteria:

- kill дает XP и soft;
- level up дает skill point;
- магазин принимает soft;
- boss дает hard;
- hard виден в lobby после возврата.

Soft shop first stat pool:

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

One-time map upgrade:

- `Power Shrine`;
- can be bought once per run;
- gives one strong temporary upgrade from the same stat pool.
- costs `300 Soft`.

## Milestone 6 - Win/Lose Loop

Цель: забег можно закончить.

Правила:

- победа после заданного количества волн;
- поражение при смерти всех игроков или по выбранному test rule;
- после конца забега игрок возвращается в lobby;
- hard сохраняется;
- временные данные сбрасываются.

Done criteria:

- можно выиграть короткий тестовый забег;
- можно проиграть;
- обе ветки возвращают игрока в lobby;
- lobby meta upgrade может быть куплен за hard.

## Первый Тестовый Scope

Чтобы быстро получить playable prototype, первый scope должен быть меньше финальной цели:

```text
Players: 1-2 for first test, architecture for 1-8
Waves: 10
Professions: 2
Enemy types: Normal, Fast, Tank, Boss
Stores: 1
One-time upgrade points: 1
Hard drop: boss wave only
```

Enemy baseline:

| Enemy | HP | Speed | Damage |
|---|---:|---:|---:|
| `Normal` | 100 | 10 | 10 |
| `Fast` | 60 | 16 | 7 |
| `Tank` | 250 | 6 | 18 |
| `Boss` | 1500 | 7 | 25 |

Enemy HP scaling: `+1%` per wave.

После этого расширяем:

```text
Players: 1-8
Waves: 30, then 100
Professions: 4+
Map: larger arena
Stores: multiple
Upgrade points: multiple
Bosses: multiple patterns
```

## Ближайшие Технические Задачи

1. Обновить config под `MaxPartySize = 8`.
2. Привести docs task board к `GDD_V2`.
3. Проверить lobby teleport на живом опубликованном experience.
4. Спроектировать data model для `Profession`, `Ability`, `Resource`.
5. Сделать ability runtime skeleton.
6. Сделать enemy cube templates.
7. Сделать minimap draft.
