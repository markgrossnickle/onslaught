--!strict
--[=[
	@class GameConfig
	Central tuning constants for Onslaught (Vampire Survivors style).
]=]

local GameConfig = {}

-- Arena (Void Wasteland)
GameConfig.Arena = {
	Radius = 100, -- circular arena
	FloorSize = Vector3.new(210, 2, 210), -- slightly larger than circle for floor part
	FloorPosition = Vector3.new(0, -1, 0),
	FloorColor = Color3.fromRGB(25, 15, 35),
	FloorMaterial = Enum.Material.Slate,

	-- Void boundary wall
	BoundaryHeight = 15,
	BoundarySegments = 32, -- how many Parts form the ring
	BoundaryColor = Color3.fromRGB(15, 8, 25),
	BoundaryTransparency = 0.8,
	BoundarySmokeColor = Color3.fromRGB(40, 15, 60),

	-- Ground veins (cosmetic glowing cracks)
	VeinCount = 25,
	VeinColor = Color3.fromRGB(180, 60, 220),
	VeinMinLength = 3,
	VeinMaxLength = 8,

	-- Void crystal obstacles
	CrystalCount = 18,
	CrystalMinHeight = 4,
	CrystalMaxHeight = 12,
	CrystalColor = Color3.fromRGB(20, 10, 35),
	CrystalCoreColor = Color3.fromRGB(140, 40, 180),
	CrystalSpawnMargin = 15,

	-- Arena evolution phases (seconds)
	Phase2Time = 300, -- 5 min
	Phase3Time = 600, -- 10 min
	Phase4Time = 840, -- 14 min (boss phase)
	FogEndPhase1 = 250,
	FogEndPhase2 = 180,
	FogEndPhase3 = 120,
	FogEndPhase4 = 80,
}

-- Player
GameConfig.Player = {
	MaxHealth = 100,
	SpawnPosition = Vector3.new(0, 5, 0),
	BaseRespawnDelay = 3,
	RespawnDelayPerDeath = 2,
	MaxRespawnDelay = 15,
	BaseWalkSpeed = 16,
	InvincibilityTime = 0.5,
	BaseMagnetRange = 15,
}

-- Player-count scaling (multiplayer balance)
GameConfig.Scaling = {
	EnemyCountPerPlayer = 0.4, -- +40% enemies per extra player
	EnemyHealthPerPlayer = 0.25, -- +25% enemy HP per extra player
	BossHealthPerPlayer = 0.5, -- +50% boss HP per extra player
}

-- Enemies (alien bug + shadow/void aesthetic)
GameConfig.Enemies = {
	SpawnDistance = 90,
	SpawnHeight = 3,
	MaxConcurrent = 200,

	Types = {
		Drone = {
			Health = 60,
			Speed = 12,
			Damage = 10,
			AttackRange = 5,
			AttackCooldown = 1.0,
			Size = Vector3.new(4, 3, 4), -- sphere-ish jellyfish
			XPValue = 10,
			-- Visual
			BodyColor = Color3.fromRGB(25, 15, 40),
			CoreColor = Color3.fromRGB(220, 60, 220), -- magenta core
			EyeColor = Color3.fromRGB(80, 220, 255), -- cyan
			Material = Enum.Material.Glass,
			TendrilCount = 5,
		},
		Brute = {
			Health = 150,
			Speed = 8,
			Damage = 25,
			AttackRange = 6,
			AttackCooldown = 1.5,
			Size = Vector3.new(6, 5, 5),
			XPValue = 25,
			BodyColor = Color3.fromRGB(20, 10, 35),
			CoreColor = Color3.fromRGB(180, 40, 180),
			EyeColor = Color3.fromRGB(255, 60, 60),
			Material = Enum.Material.Glass,
			TendrilCount = 6,
		},
		Dasher = {
			Health = 40,
			Speed = 22,
			Damage = 15,
			AttackRange = 4,
			AttackCooldown = 0.8,
			Size = Vector3.new(3, 2.5, 3),
			XPValue = 15,
			BodyColor = Color3.fromRGB(30, 10, 45),
			CoreColor = Color3.fromRGB(255, 80, 255),
			EyeColor = Color3.fromRGB(255, 120, 0),
			Material = Enum.Material.Glass,
			TendrilCount = 4,
		},
		Skitter = {
			Health = 25,
			Speed = 26,
			Damage = 8,
			AttackRange = 4,
			AttackCooldown = 0.6,
			Size = Vector3.new(3, 2, 4), -- oval spider body
			XPValue = 8,
			BodyColor = Color3.fromRGB(15, 15, 50),
			CoreColor = Color3.fromRGB(60, 255, 80), -- green core
			EyeColor = Color3.fromRGB(255, 40, 40), -- red eyes
			Material = Enum.Material.SmoothPlastic,
			LegCount = 6,
			EyeCount = 4,
		},
		Behemoth = {
			Health = 400,
			Speed = 6,
			Damage = 40,
			AttackRange = 7,
			AttackCooldown = 2.0,
			Size = Vector3.new(8, 6, 9), -- big beetle
			XPValue = 50,
			BodyColor = Color3.fromRGB(20, 10, 30),
			CoreColor = Color3.fromRGB(140, 40, 220), -- purple core
			EyeColor = Color3.fromRGB(255, 160, 30), -- orange eyes
			Material = Enum.Material.SmoothPlastic,
			LegCount = 4,
			ShellParts = 3,
		},
		Boss = {
			Health = 2000,
			Speed = 7,
			Damage = 50,
			AttackRange = 8,
			AttackCooldown = 1.5,
			Size = Vector3.new(10, 8, 10),
			XPValue = 200,
			BodyColor = Color3.fromRGB(15, 5, 25),
			CoreColor = Color3.fromRGB(255, 80, 255),
			EyeColor = Color3.fromRGB(255, 40, 40),
			Material = Enum.Material.Glass,
			TendrilCount = 8,
		},
		MegaBoss = {
			Health = 8000,
			Speed = 5,
			Damage = 60,
			AttackRange = 10,
			AttackCooldown = 1.2,
			Size = Vector3.new(16, 14, 16),
			XPValue = 500,
			BodyColor = Color3.fromRGB(10, 5, 20),
			CoreColor = Color3.fromRGB(255, 255, 255), -- white/magenta pulse
			EyeColor = Color3.fromRGB(255, 30, 30),
			Material = Enum.Material.Glass,
			TendrilCount = 10,
			ShellPlates = 6,
			-- Boss attacks
			VoidBoltInterval = 3.0,
			VoidBoltSpeed = 40,
			VoidBoltDamage = 25,
			TendrilSlamInterval = 8.0,
			TendrilSlamRadius = 20,
			TendrilSlamDamage = 35,
			TendrilSlamTelegraph = 0.5,
			SpawnMinionsInterval = 15.0,
			SpawnMinionsCount = 4,
			VoidPullInterval = 12.0,
			VoidPullDuration = 3.0,
			VoidPullSpeed = 10,
			EnrageThreshold = 0.3, -- 30% HP
		},
		Shade = {
			Health = 35,
			Speed = 18,
			Damage = 15,
			AttackRange = 5,
			AttackCooldown = 4.0, -- dive interval
			Size = Vector3.new(2, 1.5, 1.5),
			XPValue = 15,
			BodyColor = Color3.fromRGB(40, 20, 60),
			CoreColor = Color3.fromRGB(255, 40, 40),
			EyeColor = Color3.fromRGB(255, 40, 40),
			Material = Enum.Material.Glass,
			HoverHeight = 9,
			DiveSpeedMult = 2.0,
			CircleDistance = 17, -- preferred distance from player
			FlockSize = 3, -- spawns in groups
		},
		Worm = {
			Health = 30, -- per segment
			Speed = 14,
			Damage = 12,
			AttackRange = 5,
			AttackCooldown = 0.8,
			Size = Vector3.new(3, 3, 3), -- per segment
			XPValue = 5, -- per segment, +15 for head
			HeadXPBonus = 15,
			BodyColor = Color3.fromRGB(20, 10, 35),
			CoreColor = Color3.fromRGB(180, 60, 220),
			EyeColor = Color3.fromRGB(255, 40, 40),
			Material = Enum.Material.Glass,
			SegmentCount = 6,
			SegmentSpacing = 3.5,
			FragmentSpeedMult = 1.8, -- 1-segment worms charge fast
			IntroTime = 180, -- appears at 3 min
			MaxPerWave = 2,
			IntroWave = 8,
		},
	},

	-- Time-based introduction (seconds of game time)
	IntroTimes = {
		Skitter = 60,
		Shade = 120,
		Behemoth = 120,
		Worm = 180,
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
	WormIntroWave = 8,

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
	VoidDeathColor1 = Color3.fromRGB(120, 40, 180), -- purple
	VoidDeathColor2 = Color3.fromRGB(20, 10, 30), -- dark void
}

-- Power-Ups
GameConfig.PowerUps = {
	Lifetime = 15,
	BobAmplitude = 0.5,
	RotateSpeed = 2,
	OrbSize = Vector3.one * 1.8,
	MaxPowerUps = 30,

	-- Drop chances by enemy type
	DropChances = {
		Default = 0.02,
		Behemoth = 0.10,
		Boss = 0.25,
		MegaBoss = 1.0,
		Worm = 0.05,
	},

	Types = {
		HealthOrb = {
			Name = "Health Orb",
			Color = Color3.fromRGB(60, 220, 60),
			Duration = 0, -- instant
			Description = "+30 HP",
		},
		VoidShield = {
			Name = "Void Shield",
			Color = Color3.fromRGB(80, 220, 255),
			Duration = 12,
			Description = "Blocks next hit",
		},
		MagnetBurst = {
			Name = "Magnet Burst",
			Color = Color3.fromRGB(255, 220, 50),
			Duration = 0,
			Description = "Pull all XP gems",
		},
		SpeedSurge = {
			Name = "Speed Surge",
			Color = Color3.fromRGB(240, 240, 255),
			Duration = 6,
			Description = "+60% speed",
		},
		DoubleXP = {
			Name = "Double XP",
			Color = Color3.fromRGB(255, 200, 50),
			Duration = 15,
			Description = "2x XP gain",
		},
		VoidBomb = {
			Name = "Void Bomb",
			Color = Color3.fromRGB(200, 30, 30),
			Duration = 0,
			Description = "100 AoE damage",
		},
	},

	TypeList = { "HealthOrb", "VoidShield", "MagnetBurst", "SpeedSurge", "DoubleXP", "VoidBomb" },

	-- Void Chests
	ChestInterval = 90,
	ChestXPBonus = 50,
	ChestColor = Color3.fromRGB(30, 15, 50),
	ChestCoreColor = Color3.fromRGB(180, 60, 220),
	ChestMinDistFromEdge = 20,
}

return table.freeze(GameConfig)
