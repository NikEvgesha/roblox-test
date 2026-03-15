return {
	Gun = {
		ToolName = "Pistol",
		MaxMag = 12,
		StartReserve = 36,
		MaxReserve = 240,
		FireCooldown = 0.2,
		ReloadTime = 1.6,
		Range = 350,
		Damage = 20,
	},

	Sword = {
		ToolName = "Sword",
		Damage = 35,
		Cooldown = 0.7,
		Range = 7,
		SlashAnimationId = "rbxassetid://522635514",
		LungeAnimationId = "rbxassetid://522638767",
	},

	Pickups = {
		AmmoAmount = 12,
		SpawnInterval = 12,
		Lifetime = 45,
		MaxNearbyPerPlayer = 5,
		MinRadius = 8,
		MaxRadius = 16,
	},

	Sounds = {
		GunShotId = "rbxasset://sounds/swordslash.wav",
		ReloadId = "rbxasset://sounds/unsheath.wav",
		PickupId = "rbxasset://sounds/unsheath.wav",
		SwordSwingId = "rbxasset://sounds/swordlunge.wav",
	},
}
