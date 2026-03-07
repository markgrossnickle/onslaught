--!strict
--[=[
	@class GameConfig
	Central tuning constants for Onslaught.
]=]

local GameConfig = {}

-- Arena
GameConfig.Arena = {
	FloorSize = Vector3.new(200, 2, 200),
	FloorPosition = Vector3.new(0, -1, 0),
	FloorColor = Color3.fromRGB(45, 45, 48),
	WallHeight = 12,
	WallThickness = 4,
	WallColor = Color3.fromRGB(60, 60, 65),

	ObstacleCount = 12,
	ObstacleMinSize = Vector3.new(4, 6, 4),
	ObstacleMaxSize = Vector3.new(10, 10, 10),
	ObstacleColor = Color3.fromRGB(80, 80, 85),
	ObstacleSpawnMargin = 15, -- min distance from center
}

-- Player
GameConfig.Player = {
	MaxHealth = 100,
	SpawnPosition = Vector3.new(0, 5, 0),
	RespawnDelay = 3,
	BaseWalkSpeed = 16,
	BaseDamage = 25,
	InvincibilityTime = 0.5, -- seconds of i-frames after taking damage
}

-- Enemies
GameConfig.Enemies = {
	SpawnDistance = 90, -- distance from center to spawn
	SpawnHeight = 3,

	Types = {
		Grunt = {
			Health = 60,
			Speed = 12,
			Damage = 10,
			AttackRange = 5,
			AttackCooldown = 1.0,
			Color = Color3.fromRGB(200, 50, 50),
			Size = Vector3.new(4, 5, 3),
			XPReward = 10,
		},
		Brute = {
			Health = 150,
			Speed = 8,
			Damage = 25,
			AttackRange = 6,
			AttackCooldown = 1.5,
			Color = Color3.fromRGB(150, 30, 30),
			Size = Vector3.new(6, 7, 5),
			XPReward = 25,
		},
		Dasher = {
			Health = 40,
			Speed = 22,
			Damage = 15,
			AttackRange = 4,
			AttackCooldown = 0.8,
			Color = Color3.fromRGB(220, 100, 30),
			Size = Vector3.new(3, 4, 3),
			XPReward = 15,
		},
	},
}

-- Waves
GameConfig.Waves = {
	IntermissionTime = 8, -- seconds between waves
	BaseEnemyCount = 4,
	EnemiesPerWave = 2, -- additional enemies each wave
	MaxConcurrentEnemies = 30,
	SpawnInterval = 1.2, -- seconds between spawns within a wave

	-- Wave thresholds for introducing enemy types
	BruteIntroWave = 3,
	DasherIntroWave = 5,

	-- Scaling per wave
	HealthScaling = 0.08, -- +8% HP per wave
	DamageScaling = 0.05, -- +5% damage per wave
	SpeedScaling = 0.02, -- +2% speed per wave
}

-- Weapons
GameConfig.Weapons = {
	Sword = {
		Name = "Sword",
		Damage = 25,
		Range = 8,
		SwingCooldown = 0.5,
		ArcAngle = 90, -- degrees
		KnockbackForce = 30,
	},
}

-- XP / Leveling
GameConfig.XP = {
	BaseXPToLevel = 50,
	XPScaling = 1.3, -- multiplier per level
	MaxLevel = 50,
}

-- Upgrades (purchased between waves)
GameConfig.Upgrades = {
	MaxHealthUp = {
		Name = "Max Health Up",
		Description = "+20 Max Health",
		BaseCost = 30,
		CostScaling = 1.5,
		MaxStacks = 10,
		Effect = { Stat = "MaxHealth", Value = 20 },
	},
	DamageUp = {
		Name = "Damage Up",
		Description = "+10% Damage",
		BaseCost = 40,
		CostScaling = 1.5,
		MaxStacks = 10,
		Effect = { Stat = "DamageMultiplier", Value = 0.10 },
	},
	SpeedUp = {
		Name = "Speed Up",
		Description = "+2 Walk Speed",
		BaseCost = 25,
		CostScaling = 1.4,
		MaxStacks = 5,
		Effect = { Stat = "WalkSpeed", Value = 2 },
	},
	RegenUp = {
		Name = "Regen Up",
		Description = "+2 HP/sec",
		BaseCost = 35,
		CostScaling = 1.6,
		MaxStacks = 5,
		Effect = { Stat = "HealthRegen", Value = 2 },
	},
}

-- VFX
GameConfig.VFX = {
	HitFlashDuration = 0.12,
	HitFlashColor = Color3.fromRGB(255, 255, 255),
	DeathParticleCount = 15,
	DamageNumberLifetime = 1.0,
	DamageNumberRiseSpeed = 40,
}

return table.freeze(GameConfig)
