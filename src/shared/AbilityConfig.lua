local AbilityConfig = {}

AbilityConfig.EventName = "AbilityEvent"
AbilityConfig.DefaultProfession = "Gunner"
AbilityConfig.ProfessionOrder = { "Gunner", "Guardian" }

AbilityConfig.LegacyClassMap = {
	Assault = "Gunner",
	Builder = "Gunner",
	Healer = "Gunner",
	Melee = "Guardian",
}

AbilityConfig.Professions = {
	Gunner = {
		DisplayName = "Gunner",
		Resource = {
			Key = "Mana",
			DisplayName = "Mana",
			Max = 100,
			RegenPerSecond = 10,
			StartFull = true,
		},
		DefaultStance = "Pistol",
		StanceOrder = { "Pistol", "Rifle" },
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
		AbilityOrder = { "PistolTraining", "RifleTraining", "RapidHandling", "PiercingShot", "Grenade" },
		Abilities = {
			PistolTraining = {
				DisplayName = "Pistol Training",
				Type = "Passive",
				Description = "Increases pistol damage.",
			},
			RifleTraining = {
				DisplayName = "Rifle Training",
				Type = "Passive",
				Description = "Increases rifle damage.",
			},
			RapidHandling = {
				DisplayName = "Rapid Handling",
				Type = "Passive",
				Description = "Increases fire rate.",
			},
			PiercingShot = {
				DisplayName = "Piercing Shot",
				Type = "Active",
				Cost = 25,
				Cooldown = 8,
				DamageMultiplier = 2.5,
				MaxTargets = 5,
				Range = 520,
				Description = "2.5x weapon damage, pierces up to 5 enemies.",
			},
			Grenade = {
				DisplayName = "Grenade",
				Type = "Active",
				Cost = 35,
				Cooldown = 12,
				Description = "120 area damage, 12 studs radius, 0.8 sec fuse.",
			},
		},
	},

	Guardian = {
		DisplayName = "Guardian",
		Resource = {
			Key = "Rage",
			DisplayName = "Rage",
			Max = 100,
			StartFull = false,
			GainPerDamageDealt = 1 / 20,
			GainPerDamageTaken = 1 / 10,
			DecayPerSecond = 5,
			DecayDelay = 5,
		},
		AbilityOrder = { "IronSkin", "HeavyStrikes", "RageScaling", "Shield", "RageHeal", "UndyingRage", "TestAura" },
		Abilities = {
			IronSkin = {
				DisplayName = "Iron Skin",
				Type = "Passive",
				Description = "Reduces incoming damage.",
			},
			HeavyStrikes = {
				DisplayName = "Heavy Strikes",
				Type = "Passive",
				Description = "Increases melee damage.",
			},
			RageScaling = {
				DisplayName = "Rage Scaling",
				Type = "Passive",
				Description = "Increases damage per Rage.",
			},
			Shield = {
				DisplayName = "Shield",
				Type = "Active",
				Cost = 20,
				Cooldown = 10,
				ShieldMaxHealthMultiplier = 0.1,
				Duration = 6,
				Description = "Grants a shield equal to 10% max HP for 6 sec.",
			},
			RageHeal = {
				DisplayName = "Rage Heal",
				Type = "Active",
				Cost = "All",
				Cooldown = 15,
				HealMaxHealthPerRage = 0.006,
				Description = "Spends all Rage to heal up to 60% max HP at 100 Rage.",
			},
			UndyingRage = {
				DisplayName = "Undying Rage",
				Type = "Ultimate",
				Cost = "All",
				Cooldown = 60,
				Duration = 5,
				Description = "Immortal for 5 sec. HP cannot end below 1.",
			},
			TestAura = {
				DisplayName = "Test Aura",
				Type = "Aura",
				CostPerSecond = 5,
				DefenseBonus = 0.15,
				Radius = 24,
				Description = "Spends 5 Rage/sec and gives nearby allies +15% defense.",
			},
		},
	},
}

local function getProfession(professionKey)
	return AbilityConfig.Professions[professionKey]
end

function AbilityConfig.NormalizeProfessionKey(professionKey)
	if type(professionKey) == "string" then
		if getProfession(professionKey) then
			return professionKey
		end

		local mapped = AbilityConfig.LegacyClassMap[professionKey]
		if mapped and getProfession(mapped) then
			return mapped
		end
	end

	return AbilityConfig.DefaultProfession
end

function AbilityConfig.GetProfession(professionKey)
	local normalized = AbilityConfig.NormalizeProfessionKey(professionKey)
	return AbilityConfig.Professions[normalized], normalized
end

function AbilityConfig.GetDefaultStance(professionKey)
	local profession = select(1, AbilityConfig.GetProfession(professionKey))
	if not profession then
		return ""
	end

	if type(profession.DefaultStance) == "string" and profession.Stances and profession.Stances[profession.DefaultStance] then
		return profession.DefaultStance
	end

	for _, stanceKey in ipairs(profession.StanceOrder or {}) do
		if profession.Stances and profession.Stances[stanceKey] then
			return stanceKey
		end
	end

	return ""
end

function AbilityConfig.GetStance(professionKey, stanceKey)
	local profession = select(1, AbilityConfig.GetProfession(professionKey))
	if not profession or not profession.Stances then
		return nil
	end
	return profession.Stances[stanceKey]
end

function AbilityConfig.GetAbility(professionKey, abilityKey)
	local profession = select(1, AbilityConfig.GetProfession(professionKey))
	if not profession or not profession.Abilities then
		return nil
	end
	return profession.Abilities[abilityKey]
end

return AbilityConfig
