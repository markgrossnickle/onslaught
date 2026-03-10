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
	FloorColor = Color3.fromRGB(55, 35, 75),
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

-- Stages: different arena themes that rotate as the run progresses
GameConfig.Stages = {
	TransitionTime = 300, -- switch stages every 5 minutes
	List = {
		{
			Name = "VoidWasteland",
			FloorColor = Color3.fromRGB(55, 35, 75),
			FloorMaterial = Enum.Material.Slate,
			VeinColor = Color3.fromRGB(180, 60, 220),
			CrystalColor = Color3.fromRGB(35, 20, 55),
			CrystalCoreColor = Color3.fromRGB(140, 40, 180),
			BoundaryColor = Color3.fromRGB(25, 15, 40),
			BoundarySmokeColor = Color3.fromRGB(60, 25, 90),
			FogColor = Color3.fromRGB(25, 15, 40),
			TintColor = Color3.fromRGB(220, 190, 255),
			Ambient = Color3.fromRGB(80, 50, 100),
			-- Hazard: none (default stage)
			Hazard = "None",
		},
		{
			Name = "CrimsonHollow",
			FloorColor = Color3.fromRGB(70, 30, 35),
			FloorMaterial = Enum.Material.Slate,
			VeinColor = Color3.fromRGB(220, 50, 40),
			CrystalColor = Color3.fromRGB(55, 20, 20),
			CrystalCoreColor = Color3.fromRGB(220, 40, 30),
			BoundaryColor = Color3.fromRGB(40, 12, 12),
			BoundarySmokeColor = Color3.fromRGB(100, 30, 15),
			FogColor = Color3.fromRGB(30, 12, 12),
			TintColor = Color3.fromRGB(255, 190, 190),
			Ambient = Color3.fromRGB(80, 40, 40),
			-- Hazard: lava pools that deal damage
			Hazard = "LavaPools",
			HazardDamage = 8,
			HazardInterval = 15.0,
			HazardRadius = 6,
			HazardDuration = 8.0,
			HazardCount = 3,
		},
		{
			Name = "FrozenAbyss",
			FloorColor = Color3.fromRGB(40, 50, 75),
			FloorMaterial = Enum.Material.Glacier,
			VeinColor = Color3.fromRGB(60, 160, 255),
			CrystalColor = Color3.fromRGB(35, 45, 70),
			CrystalCoreColor = Color3.fromRGB(60, 140, 220),
			BoundaryColor = Color3.fromRGB(20, 25, 45),
			BoundarySmokeColor = Color3.fromRGB(30, 55, 100),
			FogColor = Color3.fromRGB(15, 20, 40),
			TintColor = Color3.fromRGB(190, 210, 255),
			Ambient = Color3.fromRGB(45, 55, 90),
			-- Hazard: ice patches that slow players
			Hazard = "IcePatches",
			HazardInterval = 12.0,
			HazardRadius = 8,
			HazardDuration = 10.0,
			HazardCount = 4,
			HazardSlowFactor = 0.5, -- 50% speed reduction
		},
		{
			Name = "EldritchNexus",
			FloorColor = Color3.fromRGB(30, 45, 30),
			FloorMaterial = Enum.Material.Slate,
			VeinColor = Color3.fromRGB(40, 220, 80),
			CrystalColor = Color3.fromRGB(20, 40, 20),
			CrystalCoreColor = Color3.fromRGB(40, 200, 60),
			BoundaryColor = Color3.fromRGB(12, 25, 12),
			BoundarySmokeColor = Color3.fromRGB(25, 70, 30),
			FogColor = Color3.fromRGB(12, 25, 12),
			TintColor = Color3.fromRGB(190, 255, 200),
			Ambient = Color3.fromRGB(40, 70, 45),
			-- Hazard: void rifts that teleport players randomly
			Hazard = "VoidRifts",
			HazardInterval = 20.0,
			HazardRadius = 5,
			HazardDuration = 6.0,
			HazardCount = 2,
		},
	},
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
		BroodQueen = {
			Health = 3000,
			Speed = 4,
			Damage = 35,
			AttackRange = 8,
			AttackCooldown = 2.0,
			Size = Vector3.new(12, 10, 12),
			XPValue = 300,
			BodyColor = Color3.fromRGB(30, 10, 40),
			CoreColor = Color3.fromRGB(220, 60, 180),
			EyeColor = Color3.fromRGB(255, 60, 60),
			Material = Enum.Material.SmoothPlastic,
			TendrilCount = 6,
			-- Attacks
			SpawnInterval = 8.0,
			SpawnCount = 5,
			PoisonPuddleInterval = 10.0,
			PoisonPuddleRadius = 8,
			PoisonPuddleDamage = 5, -- per second
			PoisonPuddleDuration = 6.0,
			EnrageThreshold = 0.3,
		},
		PhantomWeaver = {
			Health = 2500,
			Speed = 10,
			Damage = 40,
			AttackRange = 6,
			AttackCooldown = 1.0,
			Size = Vector3.new(8, 10, 8),
			XPValue = 300,
			BodyColor = Color3.fromRGB(10, 5, 25),
			CoreColor = Color3.fromRGB(140, 60, 220),
			EyeColor = Color3.fromRGB(200, 80, 255),
			Material = Enum.Material.Glass,
			TendrilCount = 4,
			-- Attacks
			TeleportInterval = 5.0,
			TeleportTelegraph = 0.8,
			CloneCount = 2,
			CloneHealth = 200,
			CloneDuration = 8.0,
			ShadowBoltInterval = 3.0,
			ShadowBoltDamage = 20,
			ShadowBoltSpeed = 35,
			EnrageThreshold = 0.3,
		},
		AbyssalSerpent = {
			Health = 3500,
			Speed = 8,
			Damage = 45,
			AttackRange = 7,
			AttackCooldown = 1.5,
			Size = Vector3.new(14, 6, 14),
			XPValue = 350,
			BodyColor = Color3.fromRGB(5, 20, 30),
			CoreColor = Color3.fromRGB(40, 180, 220),
			EyeColor = Color3.fromRGB(60, 255, 200),
			Material = Enum.Material.SmoothPlastic,
			-- Attacks
			ChargeInterval = 8.0,
			ChargeSpeed = 40,
			ChargeDamage = 50,
			ChargeDuration = 1.5,
			TailSweepInterval = 6.0,
			TailSweepRadius = 15,
			TailSweepDamage = 30,
			AcidSpitInterval = 4.0,
			AcidSpitDamage = 15,
			AcidSpitSpeed = 30,
			EnrageThreshold = 0.3,
		},
		VoidArchitect = {
			Health = 4000,
			Speed = 3,
			Damage = 30,
			AttackRange = 10,
			AttackCooldown = 2.0,
			Size = Vector3.new(10, 12, 10),
			XPValue = 400,
			BodyColor = Color3.fromRGB(15, 10, 30),
			CoreColor = Color3.fromRGB(255, 200, 60),
			EyeColor = Color3.fromRGB(255, 255, 100),
			Material = Enum.Material.Glass,
			TendrilCount = 6,
			-- Attacks
			LaserInterval = 6.0,
			LaserDamage = 10, -- per tick during sweep
			LaserDuration = 2.0,
			LaserRange = 30,
			BarrierInterval = 12.0,
			BarrierCount = 3,
			BarrierHealth = 300,
			BarrierDuration = 10.0,
			SummonInterval = 15.0,
			SummonCount = 3,
			EnrageThreshold = 0.3,
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

		-- New enemy types
		Swarmling = {
			Health = 3,
			Speed = 14,
			Damage = 3,
			AttackRange = 3,
			AttackCooldown = 0.5,
			Size = Vector3.new(0.8, 0.8, 0.8),
			XPValue = 2,
			BodyColor = Color3.fromRGB(60, 30, 80),
			CoreColor = Color3.fromRGB(255, 100, 255),
			EyeColor = Color3.fromRGB(255, 200, 255),
			Material = Enum.Material.Neon,
			FlockSize = 10,
		},
		Spitter = {
			Health = 20,
			Speed = 4,
			Damage = 8,
			AttackRange = 25,
			AttackCooldown = 3.0,
			Size = Vector3.new(4, 3, 4),
			XPValue = 15,
			BodyColor = Color3.fromRGB(20, 40, 15),
			CoreColor = Color3.fromRGB(80, 220, 40),
			EyeColor = Color3.fromRGB(200, 255, 60),
			Material = Enum.Material.SmoothPlastic,
			ProjectileSpeed = 30,
			ProjectileDamage = 8,
			RetreatRange = 10,
		},
		Lurker = {
			Health = 30,
			Speed = 8,
			Damage = 18,
			AttackRange = 5,
			AttackCooldown = 1.0,
			Size = Vector3.new(3, 3, 3),
			XPValue = 20,
			BodyColor = Color3.fromRGB(10, 5, 20),
			CoreColor = Color3.fromRGB(120, 40, 180),
			EyeColor = Color3.fromRGB(200, 60, 255),
			Material = Enum.Material.Glass,
			TeleportInterval = 4.0,
			TeleportTelegraph = 0.5,
			TeleportRange = 15, -- max distance from player to teleport
		},
		Crystalback = {
			Health = 80,
			Speed = 3,
			Damage = 20,
			AttackRange = 6,
			AttackCooldown = 1.5,
			Size = Vector3.new(5, 4, 6),
			XPValue = 35,
			BodyColor = Color3.fromRGB(20, 20, 40),
			CoreColor = Color3.fromRGB(60, 180, 255),
			EyeColor = Color3.fromRGB(100, 200, 255),
			Material = Enum.Material.SmoothPlastic,
			FrontArmorReduction = 0.5, -- 50% damage reduction from front
			ShellColor = Color3.fromRGB(80, 140, 220),
		},
		Broodmother = {
			Health = 60,
			Speed = 2,
			Damage = 10,
			AttackRange = 6,
			AttackCooldown = 2.0,
			Size = Vector3.new(6, 5, 6),
			XPValue = 40,
			BodyColor = Color3.fromRGB(30, 15, 40),
			CoreColor = Color3.fromRGB(220, 80, 180),
			EyeColor = Color3.fromRGB(255, 60, 60),
			Material = Enum.Material.SmoothPlastic,
			SpawnInterval = 6.0,
			SpawnCount = 3,
			SpawnType = "Swarmling",
		},
		Leech = {
			Health = 15,
			Speed = 10,
			Damage = 3, -- per second when attached
			AttackRange = 3,
			AttackCooldown = 1.0,
			Size = Vector3.new(1, 0.5, 2),
			XPValue = 8,
			BodyColor = Color3.fromRGB(40, 10, 30),
			CoreColor = Color3.fromRGB(180, 40, 60),
			EyeColor = Color3.fromRGB(255, 40, 40),
			Material = Enum.Material.SmoothPlastic,
			DrainDPS = 3,
			MaxAttached = 3, -- max leeches on one player
		},
		Hivemind = {
			Health = 40,
			Speed = 5,
			Damage = 10,
			AttackRange = 5,
			AttackCooldown = 1.5,
			Size = Vector3.new(4, 4, 4),
			XPValue = 30,
			BodyColor = Color3.fromRGB(25, 10, 40),
			CoreColor = Color3.fromRGB(255, 200, 60),
			EyeColor = Color3.fromRGB(255, 255, 100),
			Material = Enum.Material.Glass,
			BuffRadius = 20,
			SpeedBuff = 0.30, -- +30% speed
			DamageBuff = 0.20, -- +20% damage
		},
		Burrower = {
			Health = 35,
			Speed = 12,
			Damage = 20,
			AttackRange = 5,
			AttackCooldown = 1.0,
			Size = Vector3.new(3, 2, 5),
			XPValue = 22,
			BodyColor = Color3.fromRGB(30, 20, 15),
			CoreColor = Color3.fromRGB(180, 120, 40),
			EyeColor = Color3.fromRGB(255, 160, 30),
			Material = Enum.Material.SmoothPlastic,
			BurrowDuration = 3.0, -- time underground
			SurfaceDuration = 2.0, -- time above ground
		},
		VoidWraith = {
			Health = 50,
			Speed = 6,
			Damage = 18,
			AttackRange = 5,
			AttackCooldown = 1.2,
			Size = Vector3.new(3, 4, 3),
			XPValue = 28,
			BodyColor = Color3.fromRGB(15, 5, 25),
			CoreColor = Color3.fromRGB(160, 80, 255),
			EyeColor = Color3.fromRGB(200, 100, 255),
			Material = Enum.Material.Glass,
			PhaseInterval = 3.0, -- time between phases
			PhaseDuration = 1.0, -- time spent phased (invulnerable)
		},
	},

	-- Time-based introduction (seconds of game time)
	IntroTimes = {
		Skitter = 60,
		Shade = 120,
		Behemoth = 120,
		Worm = 180,
		Swarmling = 0,
		Spitter = 120,
		Lurker = 240,
		Crystalback = 300,
		Broodmother = 360,
		Leech = 420,
		Hivemind = 480,
		Burrower = 540,
		VoidWraith = 660,
	},
	BossInterval = 60, -- spawn a boss every N seconds
	BossStartTime = 120, -- first boss at this time
	-- Boss type rotation: cycles through these as periodic bosses spawn
	BossRotation = { "Boss", "BroodQueen", "PhantomWeaver", "AbyssalSerpent", "VoidArchitect" },
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
		HitRadius = 4.0, -- detection radius (accounts for enemy body size)
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
	VoidWhip = {
		Name = "Void Whip",
		Damage = 18,
		ArcAngle = 120, -- degrees
		Range = 12,
		FireInterval = 1.2,
		Color = Color3.fromRGB(180, 40, 255),
	},
	ShadowDaggers = {
		Name = "Shadow Daggers",
		Damage = 8, -- per dagger
		DaggerCount = 3,
		SpreadAngle = 30, -- degrees between daggers
		Speed = 70,
		Range = 50,
		FireInterval = 0.8,
		BulletSize = Vector3.new(0.4, 0.4, 1.2),
		Color = Color3.fromRGB(80, 30, 120),
	},
	GravityWell = {
		Name = "Gravity Well",
		Damage = 5, -- per tick
		Radius = 15,
		Duration = 4,
		PullSpeed = 20,
		FireInterval = 8,
		Color = Color3.fromRGB(40, 0, 80),
	},
	PlagueCloud = {
		Name = "Plague Cloud",
		Damage = 4, -- per tick
		Radius = 12,
		TickInterval = 0.5,
		SlowPercent = 0.20,
		Color = Color3.fromRGB(80, 200, 40),
	},
	VoidMissiles = {
		Name = "Void Missiles",
		Damage = 22, -- per missile
		MissileCount = 2,
		Speed = 40,
		TurnSpeed = 8, -- radians/s homing
		Range = 80,
		FireInterval = 2.5,
		BulletSize = Vector3.new(0.6, 0.6, 1.4),
		Color = Color3.fromRGB(160, 30, 200),
	},
	SpectralScythe = {
		Name = "Spectral Scythe",
		DamageOut = 15,
		DamageReturn = 20,
		Speed = 50,
		Range = 35, -- max outward distance before return
		FireInterval = 2.0,
		Size = Vector3.new(3, 0.3, 3),
		Color = Color3.fromRGB(200, 200, 255),
	},
	SoulDrain = {
		Name = "Soul Drain",
		Damage = 12, -- per second
		Range = 20,
		HealPercent = 0.20,
		TickInterval = 0.25,
		BeamColor = Color3.fromRGB(100, 255, 100),
	},
	Shockwave = {
		Name = "Shockwave",
		Damage = 25,
		Radius = 18,
		KnockbackForce = 50,
		FireInterval = 3.5,
		Color = Color3.fromRGB(255, 180, 60),
	},
}

-- Weapon level scaling (levels 1-8)
-- Each upgrade card for a weapon increments its level
GameConfig.WeaponLevels = {
	MaxLevel = 8,
	-- Per-level bonuses (multiplicative with base)
	DamagePerLevel = 0.15, -- +15% damage per level (levels 1-3 focus)
	CooldownPerLevel = 0.10, -- -10% cooldown per level (levels 4-5 focus)
	AreaPerLevel = 0.20, -- +20% area/range per level (levels 6-7 focus)
	Level8CritChance = 0.15, -- 15% crit chance at level 8
}

-- Weapon Evolutions (both ingredients must be at max level)
GameConfig.Evolutions = {
	{
		Id = "VoidNova",
		Name = "Void Nova",
		Description = "Massive pulsing explosion ring with knockback",
		Ingredients = { "Aura", "Shockwave" },
		Damage = 40,
		Radius = 20,
		TickInterval = 0.5,
		KnockbackForce = 40,
		Color = Color3.fromRGB(255, 60, 60),
	},
	{
		Id = "StormOfBlades",
		Name = "Storm of Blades",
		Description = "Spinning dagger ring that also fires outward",
		Ingredients = { "ShadowDaggers", "Orbiter" },
		OrbiterCount = 8,
		DaggerFireInterval = 0.6,
		DaggerCount = 3,
		Damage = 15,
		Color = Color3.fromRGB(120, 60, 200),
	},
	{
		Id = "DeathBeam",
		Name = "Death Beam",
		Description = "Drain beam chains across 4 enemies, heals 30%",
		Ingredients = { "SoulDrain", "Lightning" },
		Damage = 15, -- per second per target
		ChainCount = 4,
		HealPercent = 0.30,
		Range = 25,
		BeamColor = Color3.fromRGB(80, 255, 150),
	},
	{
		Id = "PlagueScythe",
		Name = "Plague Scythe",
		Description = "Scythe leaves toxic trail, cloud applies scythe damage",
		Ingredients = { "PlagueCloud", "SpectralScythe" },
		DotDamage = 20,
		ScytheDamage = 25,
		CloudRadius = 14,
		Color = Color3.fromRGB(120, 220, 60),
	},
	{
		Id = "Singularity",
		Name = "Singularity",
		Description = "Black hole that pulls enemies and launches missiles",
		Ingredients = { "GravityWell", "VoidMissiles" },
		PullRadius = 20,
		CrushDamage = 10,
		MissileCount = 8,
		MissileDamage = 15,
		Duration = 5,
		FireInterval = 10,
		Color = Color3.fromRGB(20, 0, 40),
	},
	{
		Id = "AbyssalLash",
		Name = "Abyssal Lash",
		Description = "Whip cracks fire explosive projectiles on each hit",
		Ingredients = { "VoidWhip", "Projectile" },
		WhipDamage = 30,
		ArcAngle = 120,
		Range = 14,
		ProjectilesPerHit = 2,
		ProjectileDamage = 20,
		FireInterval = 1.0,
		Color = Color3.fromRGB(220, 60, 255),
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
		-- New weapon acquisition cards
		{
			Id = "NewVoidWhip",
			Name = "Void Whip",
			Description = "Crack a whip in a 120° arc",
			MaxStacks = 1,
			Type = "Weapon",
		},
		{
			Id = "NewShadowDaggers",
			Name = "Shadow Daggers",
			Description = "Fire 3 daggers in a spread pattern",
			MaxStacks = 1,
			Type = "Weapon",
		},
		{
			Id = "NewGravityWell",
			Name = "Gravity Well",
			Description = "Drop a gravity orb that pulls and damages enemies",
			MaxStacks = 1,
			Type = "Weapon",
		},
		{
			Id = "NewPlagueCloud",
			Name = "Plague Cloud",
			Description = "Toxic cloud follows you, slowing and damaging enemies",
			MaxStacks = 1,
			Type = "Weapon",
		},
		{
			Id = "NewVoidMissiles",
			Name = "Void Missiles",
			Description = "Fire 2 homing missiles at different targets",
			MaxStacks = 1,
			Type = "Weapon",
		},
		{
			Id = "NewSpectralScythe",
			Name = "Spectral Scythe",
			Description = "Throw a boomerang scythe that returns to you",
			MaxStacks = 1,
			Type = "Weapon",
		},
		{
			Id = "NewSoulDrain",
			Name = "Soul Drain",
			Description = "Beam that drains enemy HP and heals you",
			MaxStacks = 1,
			Type = "Weapon",
		},
		{
			Id = "NewShockwave",
			Name = "Shockwave",
			Description = "Stomp the ground with a radial shockwave burst",
			MaxStacks = 1,
			Type = "Weapon",
		},
		-- New weapon upgrade cards (generic level-up per weapon)
		{
			Id = "VoidWhipUp",
			Name = "Whip Power Up",
			Description = "Increase Void Whip damage, speed, and range",
			MaxStacks = 7,
			RequiresWeapon = "VoidWhip",
			Type = "WeaponUpgrade",
		},
		{
			Id = "ShadowDaggersUp",
			Name = "Dagger Power Up",
			Description = "More daggers, faster fire, longer range",
			MaxStacks = 7,
			RequiresWeapon = "ShadowDaggers",
			Type = "WeaponUpgrade",
		},
		{
			Id = "GravityWellUp",
			Name = "Gravity Power Up",
			Description = "Stronger pull, more damage, larger radius",
			MaxStacks = 7,
			RequiresWeapon = "GravityWell",
			Type = "WeaponUpgrade",
		},
		{
			Id = "PlagueCloudUp",
			Name = "Plague Power Up",
			Description = "Larger cloud, more damage, stronger slow",
			MaxStacks = 7,
			RequiresWeapon = "PlagueCloud",
			Type = "WeaponUpgrade",
		},
		{
			Id = "VoidMissilesUp",
			Name = "Missile Power Up",
			Description = "More missiles, faster fire, higher damage",
			MaxStacks = 7,
			RequiresWeapon = "VoidMissiles",
			Type = "WeaponUpgrade",
		},
		{
			Id = "SpectralScytheUp",
			Name = "Scythe Power Up",
			Description = "Faster scythe, more damage, longer range",
			MaxStacks = 7,
			RequiresWeapon = "SpectralScythe",
			Type = "WeaponUpgrade",
		},
		{
			Id = "SoulDrainUp",
			Name = "Drain Power Up",
			Description = "Stronger drain, more healing, longer range",
			MaxStacks = 7,
			RequiresWeapon = "SoulDrain",
			Type = "WeaponUpgrade",
		},
		{
			Id = "ShockwaveUp",
			Name = "Shockwave Power Up",
			Description = "Bigger radius, more damage, faster cooldown",
			MaxStacks = 7,
			RequiresWeapon = "Shockwave",
			Type = "WeaponUpgrade",
		},
	},
}

-- Weapon unlock requirements (tracked in PlayerData.UnlockedWeapons)
GameConfig.WeaponUnlocks = {
	-- Default pool (available without unlock)
	VoidWhip = { Type = "default" },
	ShadowDaggers = { Type = "default" },
	-- Achievement-based unlocks
	GravityWell = { Type = "kills", Amount = 500 },
	PlagueCloud = { Type = "level", Amount = 15 },
	VoidMissiles = { Type = "bossKill" },
	SpectralScythe = { Type = "survivalTime", Amount = 600 },
	SoulDrain = { Type = "gemsCollected", Amount = 1000 },
	Shockwave = { Type = "killsInRun", Amount = 50 },
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

-- Mobile overrides (TouchEnabled + no keyboard)
GameConfig.Mobile = {
	MaxConcurrentEnemies = 120,
	MaxGems = 150,
	ParticleRateMult = 0.5,
	TrailLifetimeMult = 0.5,
	CameraDistanceMult = 1.2,
	AnimFrameSkip = 2, -- animate every Nth frame
}

-- Console overrides (ten-foot interface)
GameConfig.Console = {
	TextSizeMult = 1.2,
}

return table.freeze(GameConfig)
