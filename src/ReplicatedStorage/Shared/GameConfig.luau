--!strict
--[=[
	@class GameConfig
	Central tuning constants for Onslaught (Vampire Survivors style).
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
	ObstacleSpawnMargin = 15,
}

-- Player
GameConfig.Player = {
	MaxHealth = 100,
	SpawnPosition = Vector3.new(0, 5, 0),
	RespawnDelay = 3,
	BaseWalkSpeed = 16,
	InvincibilityTime = 0.5,
	BaseMagnetRange = 15,
}

-- Enemies
GameConfig.Enemies = {
	SpawnDistance = 90,
	SpawnHeight = 3,
	MaxConcurrent = 200,

	Types = {
		Grunt = {
			Health = 60,
			Speed = 12,
			Damage = 10,
			AttackRange = 5,
			AttackCooldown = 1.0,
			Color = Color3.fromRGB(200, 50, 50),
			Size = Vector3.new(4, 5, 3),
			XPValue = 10,
		},
		Brute = {
			Health = 150,
			Speed = 8,
			Damage = 25,
			AttackRange = 6,
			AttackCooldown = 1.5,
			Color = Color3.fromRGB(150, 30, 30),
			Size = Vector3.new(6, 7, 5),
			XPValue = 25,
		},
		Dasher = {
			Health = 40,
			Speed = 22,
			Damage = 15,
			AttackRange = 4,
			AttackCooldown = 0.8,
			Color = Color3.fromRGB(220, 100, 30),
			Size = Vector3.new(3, 4, 3),
			XPValue = 15,
		},
		Runner = {
			Health = 25,
			Speed = 26,
			Damage = 8,
			AttackRange = 4,
			AttackCooldown = 0.6,
			Color = Color3.fromRGB(255, 60, 60),
			Size = Vector3.new(2, 3, 2),
			XPValue = 8,
		},
		Tank = {
			Health = 400,
			Speed = 6,
			Damage = 40,
			AttackRange = 7,
			AttackCooldown = 2.0,
			Color = Color3.fromRGB(120, 50, 180),
			Size = Vector3.new(8, 9, 7),
			XPValue = 50,
		},
		Boss = {
			Health = 2000,
			Speed = 7,
			Damage = 50,
			AttackRange = 8,
			AttackCooldown = 1.5,
			Color = Color3.fromRGB(255, 180, 30),
			Size = Vector3.new(12, 14, 10),
			XPValue = 200,
		},
	},

	-- Time-based introduction (seconds of game time)
	IntroTimes = {
		Runner = 60,
		Tank = 120,
	},
	BossInterval = 60, -- spawn a boss every N seconds
	BossStartTime = 120, -- first boss at this time
}

-- Waves
GameConfig.Waves = {
	IntermissionTime = 5,
	BaseEnemyCount = 5,
	EnemiesPerWave = 3,
	SpawnInterval = 1.0,

	BruteIntroWave = 3,
	DasherIntroWave = 5,

	HealthScaling = 0.08,
	DamageScaling = 0.05,
	SpeedScaling = 0.02,

	-- Spawn rate acceleration: spawn interval decreases over time
	MinSpawnInterval = 0.3,
	SpawnIntervalDecayPerWave = 0.05,
}

-- Auto-Attack Weapons
GameConfig.Weapons = {
	Orbiter = {
		Name = "Orbiter",
		Damage = 12,
		OrbitRadius = 8,
		OrbitSpeed = 3.0,
		SphereSize = 1.8,
		Color = Color3.fromRGB(100, 180, 255),
		HitCooldown = 0.5,
		InitialCount = 2,
	},
	Projectile = {
		Name = "Projectile",
		Damage = 20,
		Speed = 80,
		FireInterval = 1.5,
		BulletSize = Vector3.new(0.8, 0.8, 1.6),
		Color = Color3.fromRGB(255, 220, 50),
		Range = 60,
		Pierce = 1,
	},
	Lightning = {
		Name = "Lightning",
		Damage = 35,
		Range = 25,
		FireInterval = 2.0,
		ChainCount = 1, -- how many targets it chains to
		ChainRange = 15, -- range for chain jumps
		BeamColor = Color3.fromRGB(150, 120, 255),
		BeamDuration = 0.2,
	},
	Aura = {
		Name = "Aura",
		Damage = 5, -- per tick
		Radius = 10,
		TickInterval = 0.5,
		Color = Color3.fromRGB(255, 100, 100),
	},
}

-- XP Gems
GameConfig.XPGems = {
	Size = Vector3.new(1.2, 1.2, 1.2),
	Color = Color3.fromRGB(80, 255, 120),
	GlowColor = Color3.fromRGB(120, 255, 160),
	MagnetSpeed = 60,
	Lifetime = 30,
	MaxGems = 300, -- cap to prevent performance issues
}

-- XP / Leveling
GameConfig.XP = {
	BaseXPToLevel = 50,
	XPScaling = 1.3,
	MaxLevel = 50,
}

-- Level-Up Upgrade Cards
GameConfig.UpgradeCards = {
	CardsOffered = 3,

	Options = {
		{
			Id = "NewProjectile",
			Name = "Projectile",
			Description = "Gain auto-firing projectile weapon",
			MaxStacks = 1,
			Type = "Weapon",
		},
		{
			Id = "NewLightning",
			Name = "Lightning",
			Description = "Zap nearest enemy with chaining beam",
			MaxStacks = 1,
			Type = "Weapon",
		},
		{
			Id = "NewAura",
			Name = "Damage Aura",
			Description = "Constant AoE damage ring around you",
			MaxStacks = 1,
			Type = "Weapon",
		},
		{
			Id = "OrbiterCount",
			Name = "+1 Orbiter",
			Description = "Add another orbiting sphere",
			MaxStacks = 4,
			Type = "WeaponUpgrade",
		},
		{
			Id = "DamageUp",
			Name = "Damage +25%",
			Description = "All weapons deal 25% more damage",
			MaxStacks = 8,
			Type = "Stat",
		},
		{
			Id = "SpeedUp",
			Name = "Move Speed +20%",
			Description = "Move 20% faster",
			MaxStacks = 5,
			Type = "Stat",
		},
		{
			Id = "RegenUp",
			Name = "Regen +2/s",
			Description = "Regenerate 2 HP per second",
			MaxStacks = 5,
			Type = "Stat",
		},
		{
			Id = "MagnetUp",
			Name = "Magnet +50%",
			Description = "XP gem pickup range +50%",
			MaxStacks = 5,
			Type = "Stat",
		},
		{
			Id = "MaxHealthUp",
			Name = "Max HP +25",
			Description = "Increase maximum health by 25",
			MaxStacks = 8,
			Type = "Stat",
		},
		{
			Id = "ProjectilePierce",
			Name = "Pierce +1",
			Description = "Projectiles hit one more enemy",
			MaxStacks = 4,
			RequiresWeapon = "Projectile",
			Type = "WeaponUpgrade",
		},
		{
			Id = "ProjectileSpeed",
			Name = "Fire Rate Up",
			Description = "Projectiles fire 20% faster",
			MaxStacks = 4,
			RequiresWeapon = "Projectile",
			Type = "WeaponUpgrade",
		},
		{
			Id = "LightningChain",
			Name = "Chain +1",
			Description = "Lightning chains to one more enemy",
			MaxStacks = 4,
			RequiresWeapon = "Lightning",
			Type = "WeaponUpgrade",
		},
		{
			Id = "AuraRadius",
			Name = "Aura Radius +30%",
			Description = "Damage aura covers more area",
			MaxStacks = 5,
			RequiresWeapon = "Aura",
			Type = "WeaponUpgrade",
		},
		{
			Id = "AuraDamage",
			Name = "Aura Damage +40%",
			Description = "Damage aura hits harder",
			MaxStacks = 5,
			RequiresWeapon = "Aura",
			Type = "WeaponUpgrade",
		},
	},
}

-- Camera
GameConfig.Camera = {
	Distance = 50,
	Angle = 60,
	FieldOfView = 50,
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
