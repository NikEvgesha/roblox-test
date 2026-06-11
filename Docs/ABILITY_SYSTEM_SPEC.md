# Ability System Spec

## Status

Active technical direction for the cube prototype.

## Core Decision

Keep the existing combat layer as a low-level foundation and build an ability-first layer above it.

Existing systems stay useful for:

- ranged hit detection;
- melee hit detection;
- damage application;
- weapon tools;
- tracers and muzzle flash;
- combat audio;
- shop draft;
- wave/enemy draft.

New systems own the actual game rules:

- profession selection;
- profession resources;
- ability unlocks;
- ability upgrades;
- stance switching;
- active ability cooldowns;
- aura toggles;
- passive stat modifiers.

The goal is to avoid rewriting working combat mechanics while moving the design away from a weapon-only game.

## Runtime Layers

```text
Player Input
  -> AbilityController (client)
  -> AbilityRequest RemoteEvent
  -> AbilityService (server)
  -> ProfessionState / ResourceState / CooldownState
  -> Combat Adapter (existing fire/melee/damage systems)
```

## Shared Config Shape

Ability definitions should live in shared config so both client and server can render UI and validate actions.

Draft structure:

```lua
ProfessionConfig = {
	Gunner = {
		DisplayName = "Gunner",
		Resource = "Mana",
		MaxResource = 100,
		ResourceRegenPerSecond = 10,
		DefaultStance = "Pistol",
		Stances = {
			Pistol = {
				DisplayName = "Pistol",
				WeaponKey = "Pistol",
				ResourceCostPerShot = 0,
			},
			Rifle = {
				DisplayName = "Rifle",
				WeaponKey = "Rifle",
				ResourceCostPerShot = 3,
			},
		},
		Abilities = {
			PistolTraining = { Type = "Passive" },
			RifleTraining = { Type = "Passive" },
			RapidHandling = { Type = "Passive" },
			PiercingShot = { Type = "Active" },
			Grenade = { Type = "Active" },
		},
	},
}
```

## Server Authority

The server is authoritative for:

- selected profession;
- resource amount;
- cooldowns;
- ability unlock state;
- ability rank;
- damage multipliers;
- hard/soft/XP rewards;
- death and run completion.

The client can predict simple UI changes, but server state wins.

## Client Responsibilities

The client owns:

- hotbar UI;
- resource bar UI;
- cooldown visuals;
- input mapping;
- local targeting preview;
- stance indicator;
- minimap display.

The client sends intent, not final results.

Examples:

```text
UseAbility("PiercingShot", targetData)
SetStance("Rifle")
ToggleAura("TestAura", true)
```

## Resource Rules

### Mana

Used by `Gunner`.

Prototype values:

- max: `100`;
- regen: `10/sec`;
- Rifle shot cost: `3 Mana`.

Mana is a smooth resource. It regenerates over time and limits sustained stronger actions.

### Rage

Used by `Guardian`.

Prototype values:

- max: `100`;
- gain: `1 Rage / 20 dealt damage`;
- gain: `1 Rage / 10 taken damage`;
- decay: `5/sec` after `5` seconds out of combat.

Rage is a combat pressure resource. It rewards being active and taking risks.

## Ability Types

### Passive

Passive abilities apply stat modifiers while unlocked.

Examples:

- pistol damage bonus;
- rifle damage bonus;
- fire rate bonus;
- melee damage bonus;
- damage reduction;
- damage per Rage.

### Active

Active abilities trigger once and go on cooldown.

Examples:

- `Piercing Shot`;
- `Grenade`;
- `Shield`;
- `Rage Heal`;
- `Undying Rage`.

### Stance

Stances are mutually exclusive modes.

Prototype:

- `Gunner.Pistol`;
- `Gunner.Rifle`.

Guardian has no stance in the first prototype.

### Aura

Auras are toggle abilities with recurring cost or recurring effect.

Prototype:

- Gunner has no aura.
- Guardian has temporary `Test Aura` for validation: it spends `5 Rage/sec` and gives nearby allies `+15% defense`.

## Combat Adapter Contract

AbilitySystem should call existing combat functions through small server-side adapters instead of duplicating damage logic.

Draft adapter responsibilities:

- apply ranged shot modifiers;
- apply melee damage modifiers;
- apply temporary damage reduction;
- apply shield HP before health damage;
- spawn ability projectiles or area effects;
- notify combat feedback UI.

If current combat code is too coupled, create a thin `CombatRuntime` ModuleScript and move reusable damage/stat functions there gradually.

## Gunner Prototype

Resource: `Mana`.

Stance:

- `Pistol`: normal shots, no mana cost.
- `Rifle`: shots cost `3 Mana`.

Abilities:

| Key | Type | Prototype Effect |
|---|---|---|
| `PistolTraining` | Passive | increases pistol damage |
| `RifleTraining` | Passive | increases rifle damage |
| `RapidHandling` | Passive | increases fire rate |
| `PiercingShot` | Active | line shot that hits multiple enemies |
| `Grenade` | Active | area damage after short delay |

Active numbers:

| Skill | Cost | Cooldown | Effect |
|---|---:|---:|---|
| `PiercingShot` | 25 Mana | 8 sec | `2.5x weapon damage`, pierces up to `5` enemies |
| `Grenade` | 35 Mana | 12 sec | `120 damage`, `12 studs` radius, `0.8 sec` fuse |

## Guardian Prototype

Resource: `Rage`.

Abilities:

| Key | Type | Prototype Effect |
|---|---|---|
| `IronSkin` | Passive | reduces incoming damage |
| `HeavyStrikes` | Passive | increases melee damage |
| `RageScaling` | Passive | increases damage per Rage |
| `Shield` | Active | shield equal to `10% max HP` |
| `RageHeal` | Active | spends all Rage to heal |
| `UndyingRage` | Ultimate | spends current Rage, immortal for `5s`, can gain Rage, cannot drop below `1 HP` |
| `TestAura` | Aura | spends `5 Rage/sec`, gives nearby allies `+15% defense` |

Active numbers:

| Skill | Cost | Cooldown | Effect |
|---|---:|---:|---|
| `Shield` | 20 Rage | 10 sec | shield equal to `10% max HP`, lasts `6 sec` |
| `RageHeal` | all Rage | 15 sec | heals `0.6% max HP` per Rage; `100 Rage = 60% max HP` |
| `UndyingRage` | all Rage | 60 sec | immortal for `5 sec`, HP cannot end below `1` |

## First Implementation Milestone

Do not implement every ability immediately.

First code slice:

1. Add shared profession/ability config.
2. Add server `AbilityService`.
3. Add client `AbilityController`.
4. Add resource replication for Mana/Rage.
5. Implement Gunner stance switch.
6. Make Rifle shots consume Mana.
7. Implement Guardian Rage gain/decay.
8. Show resource bars in draft UI.

After that:

1. Add one Gunner active: `PiercingShot`.
2. Add one Guardian active: `Shield`.
3. Add passives.
4. Add `Grenade`, `RageHeal`, `UndyingRage`.
5. Add `TestAura`.

Current implementation status 2026-06-11:

- First code slice is implemented.
- `PiercingShot`, `Grenade`, `Shield`, `RageHeal`, `UndyingRage`, and `TestAura` are implemented enough for prototype testing.
- Ability ranks are implemented in runtime state and upgraded through `Progression.SkillPoints`.
- Gunner passives affect ranged weapon damage and fire rate.
- Guardian passives affect incoming damage, melee damage, and damage scaling from current Rage.
- Remaining cleanup: split the large combat and zombie scripts into smaller services after the cube loop is playable.

## Open Technical Questions

1. Whether ability ranks remain run-only or later merge with lobby/meta progression.
2. Exact final layout for the rank/ability UI.
3. How much of `combat.server.lua` and `zombies.server.lua` should be split into modules after prototype validation.
