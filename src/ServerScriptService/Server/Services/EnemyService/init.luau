--!strict
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

export type EnemyData = {
	Model: Model,
	Type: string,
	Health: number,
	MaxHealth: number,
	Speed: number,
	Damage: number,
	AttackRange: number,
	AttackCooldown: number,
	XPValue: number,
	LastAttackTime: number,
	Target: Player?,
	Alive: boolean,
	-- Shade-specific
	ShadeState: string?, -- "CIRCLE" | "DIVE" | "ASCEND"
	DiveTarget: Vector3?,
	AscendUntil: number?,
	-- Boss-specific
	BossState: string?, -- "CHASE" | "SLAM" | "SPAWN" | "PULL"
	BossStateUntil: number?,
	LastVoidBolt: number?,
	LastSlam: number?,
	LastSpawnMinions: number?,
	LastVoidPull: number?,
	VoidPullUntil: number?,
	-- Worm-specific
	WormId: number?, -- shared across all segments of same worm
	IsWormHead: boolean?,
	SegmentIndex: number?,
	-- Spitter-specific
	LastSpitTime: number?,
	-- Lurker-specific
	LastTeleportTime: number?,
	TeleportPhase: string?, -- "VISIBLE" | "TELEGRAPH" | "TELEPORTING"
	TeleportPhaseUntil: number?,
	-- Broodmother-specific
	LastSpawnTime: number?,
	-- Leech-specific
	AttachedTo: Player?,
	-- Burrower-specific
	BurrowState: string?, -- "BURROWED" | "SURFACED"
	BurrowStateUntil: number?,
	-- VoidWraith-specific
	PhaseState: string?, -- "SOLID" | "PHASED"
	PhaseStateUntil: number?,
	-- Hivemind-specific (no extra fields needed, buff applied in AI)
	-- BroodQueen-specific
	LastPoisonPuddle: number?,
	-- PhantomWeaver-specific
	LastShadowBolt: number?,
	LastCloneSpawn: number?,
	-- AbyssalSerpent-specific
	ChargeState: string?, -- "IDLE" | "CHARGING"
	ChargeDirection: Vector3?,
	ChargeUntil: number?,
	LastCharge: number?,
	LastTailSweep: number?,
	LastAcidSpit: number?,
	-- VoidArchitect-specific
	LaserState: string?, -- "IDLE" | "FIRING"
	LaserUntil: number?,
	LaserTarget: Vector3?,
	LastLaser: number?,
	LastBarrier: number?,
	LastSummon: number?,
}

export type WormData = {
	Id: number,
	Segments: { EnemyData }, -- ordered head to tail
	Alive: boolean,
}

local EnemyService = Knit.CreateService({
	Name = "EnemyService",
	Client = {
		EnemyDamaged = Knit.CreateSignal(),
		EnemyKilled = Knit.CreateSignal(),
		VoidBoltFired = Knit.CreateSignal(), -- (startPos, direction)
		TendrilSlam = Knit.CreateSignal(), -- (position, radius)
		VoidPullStarted = Knit.CreateSignal(), -- (position, duration)
		BossHealthUpdate = Knit.CreateSignal(), -- (healthPct, enraged)
		PoisonPuddlePlaced = Knit.CreateSignal(), -- (position, radius, duration)
		ShadowBoltFired = Knit.CreateSignal(), -- (startPos, direction)
		BossCharge = Knit.CreateSignal(), -- (startPos, endPos)
		TailSweep = Knit.CreateSignal(), -- (position, radius)
		BossLaser = Knit.CreateSignal(), -- (startPos, targetPos, duration)
		BarrierPlaced = Knit.CreateSignal(), -- (position)
	},

	EnemyKilled = Signal.new(), -- (enemyData, killerPlayer)
})

local _enemies: { EnemyData } = {}
local _worms: { WormData } = {}
local _nextWormId: number = 1
local _enemyFolder: Folder = nil :: any
local _spawning: boolean = false
local _lastBossSpawnTime: number = 0
local _bossSpawnCount: number = 0
local _megaBossEnemy: EnemyData? = nil
local _enraged: boolean = false

local BOSS_TYPES: { [string]: boolean } = {
	Boss = true,
	MegaBoss = true,
	BroodQueen = true,
	PhantomWeaver = true,
	AbyssalSerpent = true,
	VoidArchitect = true,
}

local GameService: any
local ArenaService: any
local CombatService: any
local StatsService: any

-------------------------------------------------
-- HELPER: create smoke emitter for void enemies
-------------------------------------------------
local function addVoidSmoke(parent: BasePart, color: Color3, rate: number?)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "VoidSmoke"
	emitter.Color = ColorSequence.new(color, Color3.fromRGB(0, 0, 0))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 2) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.5, 1.2)
	emitter.Rate = rate or 6
	emitter.Speed = NumberRange.new(0.5, 2)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission = 0.2
	emitter.Parent = parent
end

-------------------------------------------------
-- HELPER: create appendage and tag it
-------------------------------------------------
local function tagAppendage(part: BasePart, appendageType: string, index: number)
	CollectionService:AddTag(part, "EnemyAppendage")
	part:SetAttribute("AppendageType", appendageType)
	part:SetAttribute("AppendageIndex", index)
end

-------------------------------------------------
-- HELPER: add health bar billboard
-------------------------------------------------
local function addHealthBar(model: Model, body: BasePart, yOffset: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HealthBar"
	billboard.Size = UDim2.new(0, 60, 0, 8)
	billboard.StudsOffset = Vector3.new(0, yOffset, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = body
	billboard.Parent = model

	local bgBar = Instance.new("Frame")
	bgBar.Name = "Background"
	bgBar.Size = UDim2.new(1, 0, 1, 0)
	bgBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	bgBar.BorderSizePixel = 0
	bgBar.Parent = billboard

	local fillBar = Instance.new("Frame")
	fillBar.Name = "Fill"
	fillBar.Size = UDim2.new(1, 0, 1, 0)
	fillBar.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
	fillBar.BorderSizePixel = 0
	fillBar.Parent = bgBar
end

-------------------------------------------------
-- HELPER: add body movers
-------------------------------------------------
local function addBodyMovers(body: BasePart, speed: number, position: Vector3)
	local attachment = Instance.new("Attachment")
	attachment.Name = "MoveAttachment"
	attachment.Parent = body

	local alignPosition = Instance.new("AlignPosition")
	alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
	alignPosition.Attachment0 = attachment
	alignPosition.MaxForce = 50000
	alignPosition.MaxVelocity = speed
	alignPosition.Responsiveness = 15
	alignPosition.Position = position
	alignPosition.Parent = body

	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = attachment
	alignOrientation.MaxTorque = 50000
	alignOrientation.Responsiveness = 20
	alignOrientation.Parent = body
end

-------------------------------------------------
-- MODEL BUILDERS
-------------------------------------------------

local function buildDroneModel(cfg: any, position: Vector3, model: Model): BasePart
	-- Glass dome body
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = cfg.Size
	body.Color = cfg.BodyColor
	body.Material = cfg.Material
	body.Transparency = 0.3
	body.Position = position
	body.Anchored = false
	body.CanCollide = true
	body.Parent = model

	-- Neon core inside
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Shape = Enum.PartType.Ball
	core.Size = cfg.Size * 0.35
	core.Color = cfg.CoreColor
	core.Material = Enum.Material.Neon
	core.Anchored = false
	core.CanCollide = false
	core.CastShadow = false
	core.Parent = model

	local coreWeld = Instance.new("WeldConstraint")
	coreWeld.Part0 = body
	coreWeld.Part1 = core
	coreWeld.Parent = core
	core.CFrame = body.CFrame

	-- Eyes (2 cyan)
	for i = 1, 2 do
		local eye = Instance.new("Part")
		eye.Name = "Eye" .. i
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.one * 0.5
		eye.Color = cfg.EyeColor
		eye.Material = Enum.Material.Neon
		eye.Anchored = false
		eye.CanCollide = false
		eye.CastShadow = false
		eye.Parent = model

		local xOff = (i == 1) and -0.7 or 0.7
		eye.CFrame = body.CFrame * CFrame.new(xOff, 0.3, -cfg.Size.Z / 2 - 0.15)

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = eye
		weld.Parent = eye
	end

	-- Hanging tendrils
	local tendrilCount = cfg.TendrilCount or 5
	for i = 1, tendrilCount do
		local tendril = Instance.new("Part")
		tendril.Name = "Tendril" .. i
		tendril.Size = Vector3.new(0.2, 3 + math.random() * 1.5, 0.2)
		tendril.Color = cfg.BodyColor
		tendril.Material = Enum.Material.SmoothPlastic
		tendril.Transparency = 0.2
		tendril.Anchored = false
		tendril.CanCollide = false
		tendril.CastShadow = false
		tendril.Parent = model

		local angle = (i / tendrilCount) * math.pi * 2
		local radius = cfg.Size.X * 0.3
		local xOff = math.cos(angle) * radius
		local zOff = math.sin(angle) * radius
		tendril.CFrame = body.CFrame * CFrame.new(xOff, -cfg.Size.Y / 2 - tendril.Size.Y / 2, zOff)

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = tendril
		weld.Parent = tendril

		tagAppendage(tendril, "Tendril", i)
	end

	addVoidSmoke(body, cfg.CoreColor)

	return body
end

local function buildSkitterModel(cfg: any, position: Vector3, model: Model): BasePart
	-- Oval spider body
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = cfg.Size
	body.Color = cfg.BodyColor
	body.Material = cfg.Material
	body.Position = position
	body.Anchored = false
	body.CanCollide = true
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Parent = model

	-- Green core (top)
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.one * 1.0
	core.Color = cfg.CoreColor
	core.Material = Enum.Material.Neon
	core.Anchored = false
	core.CanCollide = false
	core.CastShadow = false
	core.Parent = model
	core.CFrame = body.CFrame * CFrame.new(0, cfg.Size.Y * 0.3, 0)

	local coreWeld = Instance.new("WeldConstraint")
	coreWeld.Part0 = body
	coreWeld.Part1 = core
	coreWeld.Parent = core

	-- 4 red eyes
	local eyeCount = cfg.EyeCount or 4
	for i = 1, eyeCount do
		local eye = Instance.new("Part")
		eye.Name = "Eye" .. i
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.one * 0.3
		eye.Color = cfg.EyeColor
		eye.Material = Enum.Material.Neon
		eye.Anchored = false
		eye.CanCollide = false
		eye.CastShadow = false
		eye.Parent = model

		local xOff = ((i - 1) / (eyeCount - 1) - 0.5) * cfg.Size.X * 0.6
		local yOff = (i % 2 == 0) and 0.1 or -0.1
		eye.CFrame = body.CFrame * CFrame.new(xOff, cfg.Size.Y * 0.15 + yOff, -cfg.Size.Z / 2 - 0.1)

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = eye
		weld.Parent = eye
	end

	-- 6 legs
	local legCount = cfg.LegCount or 6
	for i = 1, legCount do
		local leg = Instance.new("Part")
		leg.Name = "Leg" .. i
		leg.Size = Vector3.new(0.25, 2.5, 0.25)
		leg.Color = cfg.BodyColor
		leg.Material = Enum.Material.SmoothPlastic
		leg.Anchored = false
		leg.CanCollide = false
		leg.CastShadow = false
		leg.Parent = model

		local side = (i <= legCount / 2) and -1 or 1
		local legIdx = ((i - 1) % (legCount / 2))
		local zOff = (legIdx / (legCount / 2 - 1) - 0.5) * cfg.Size.Z * 0.7
		leg.CFrame = body.CFrame
			* CFrame.new(side * cfg.Size.X / 2, -cfg.Size.Y / 2, zOff)
			* CFrame.Angles(0, 0, side * math.rad(35))

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = leg
		weld.Parent = leg

		tagAppendage(leg, "Leg", i)
	end

	addVoidSmoke(body, cfg.CoreColor, 4)

	return body
end

local function buildBehemothModel(cfg: any, position: Vector3, model: Model): BasePart
	-- Large dark carapace
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = cfg.Size
	body.Color = cfg.BodyColor
	body.Material = cfg.Material
	body.Position = position
	body.Anchored = false
	body.CanCollide = true
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Parent = model

	-- Shell wedge plates on top
	local shellParts = cfg.ShellParts or 3
	for i = 1, shellParts do
		local shell = Instance.new("WedgePart")
		shell.Name = "Shell" .. i
		shell.Size = Vector3.new(cfg.Size.X * 0.7, cfg.Size.Y * 0.3, cfg.Size.Z * 0.25)
		shell.Color = Color3.fromRGB(30, 15, 45)
		shell.Material = Enum.Material.SmoothPlastic
		shell.Anchored = false
		shell.CanCollide = false
		shell.CastShadow = false
		shell.Parent = model

		local zOff = ((i - 1) / (shellParts - 1) - 0.5) * cfg.Size.Z * 0.6
		shell.CFrame = body.CFrame * CFrame.new(0, cfg.Size.Y / 2 + shell.Size.Y / 2, zOff)

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = shell
		weld.Parent = shell
	end

	-- Purple core (underbelly glow)
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.one * 2.5
	core.Color = cfg.CoreColor
	core.Material = Enum.Material.Neon
	core.Anchored = false
	core.CanCollide = false
	core.CastShadow = false
	core.Parent = model
	core.CFrame = body.CFrame * CFrame.new(0, -cfg.Size.Y * 0.2, 0)

	local coreWeld = Instance.new("WeldConstraint")
	coreWeld.Part0 = body
	coreWeld.Part1 = core
	coreWeld.Parent = core

	-- Horn
	local horn = Instance.new("Part")
	horn.Name = "Horn"
	horn.Size = Vector3.new(0.6, 3, 0.6)
	horn.Color = Color3.fromRGB(40, 20, 60)
	horn.Material = Enum.Material.SmoothPlastic
	horn.Anchored = false
	horn.CanCollide = false
	horn.CastShadow = false
	horn.Parent = model
	horn.CFrame = body.CFrame
		* CFrame.new(0, cfg.Size.Y * 0.3, -cfg.Size.Z / 2 - 0.5)
		* CFrame.Angles(math.rad(-30), 0, 0)

	local hornWeld = Instance.new("WeldConstraint")
	hornWeld.Part0 = body
	hornWeld.Part1 = horn
	hornWeld.Parent = horn

	-- Orange eyes (2)
	for i = 1, 2 do
		local eye = Instance.new("Part")
		eye.Name = "Eye" .. i
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.one * 0.7
		eye.Color = cfg.EyeColor
		eye.Material = Enum.Material.Neon
		eye.Anchored = false
		eye.CanCollide = false
		eye.CastShadow = false
		eye.Parent = model

		local xOff = (i == 1) and -1.2 or 1.2
		eye.CFrame = body.CFrame * CFrame.new(xOff, cfg.Size.Y * 0.2, -cfg.Size.Z / 2 - 0.2)

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = eye
		weld.Parent = eye
	end

	-- 4 thick legs
	local legCount = cfg.LegCount or 4
	for i = 1, legCount do
		local leg = Instance.new("Part")
		leg.Name = "Leg" .. i
		leg.Size = Vector3.new(0.8, 4, 0.8)
		leg.Color = cfg.BodyColor
		leg.Material = Enum.Material.SmoothPlastic
		leg.Anchored = false
		leg.CanCollide = false
		leg.CastShadow = false
		leg.Parent = model

		local side = (i <= legCount / 2) and -1 or 1
		local legIdx = ((i - 1) % (legCount / 2))
		local zOff = (legIdx == 0) and -cfg.Size.Z * 0.3 or cfg.Size.Z * 0.3
		leg.CFrame = body.CFrame
			* CFrame.new(side * cfg.Size.X / 2, -cfg.Size.Y / 2, zOff)
			* CFrame.Angles(0, 0, side * math.rad(15))

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = leg
		weld.Parent = leg

		tagAppendage(leg, "Leg", i)
	end

	addVoidSmoke(body, cfg.CoreColor, 10)

	return body
end

local function buildShadeModel(cfg: any, position: Vector3, model: Model): BasePart
	-- Small dark oval body
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = cfg.Size
	body.Color = cfg.BodyColor
	body.Material = cfg.Material
	body.Transparency = 0.15
	body.Position = position + Vector3.new(0, cfg.HoverHeight or 9, 0)
	body.Anchored = false
	body.CanCollide = true
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Parent = model

	-- Tiny red core
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.one * 0.5
	core.Color = cfg.CoreColor
	core.Material = Enum.Material.Neon
	core.Anchored = false
	core.CanCollide = false
	core.CastShadow = false
	core.Parent = model
	core.CFrame = body.CFrame

	local coreWeld = Instance.new("WeldConstraint")
	coreWeld.Part0 = body
	coreWeld.Part1 = core
	coreWeld.Parent = core

	-- Two red eyes
	for i = 1, 2 do
		local eye = Instance.new("Part")
		eye.Name = "Eye" .. i
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.one * 0.25
		eye.Color = cfg.EyeColor
		eye.Material = Enum.Material.Neon
		eye.Anchored = false
		eye.CanCollide = false
		eye.CastShadow = false
		eye.Parent = model

		local xOff = (i == 1) and -0.35 or 0.35
		eye.CFrame = body.CFrame * CFrame.new(xOff, 0.15, -cfg.Size.Z / 2 - 0.1)

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = eye
		weld.Parent = eye
	end

	-- Wings (WedgeParts)
	for i = 1, 2 do
		local wing = Instance.new("WedgePart")
		wing.Name = "Wing" .. i
		wing.Size = Vector3.new(3, 0.1, 2)
		wing.Color = Color3.fromRGB(20, 10, 40)
		wing.Material = Enum.Material.SmoothPlastic
		wing.Anchored = false
		wing.CanCollide = false
		wing.CastShadow = false
		wing.Parent = model

		local side = (i == 1) and -1 or 1
		wing.CFrame = body.CFrame * CFrame.new(side * (cfg.Size.X / 2 + 1.2), 0, 0)

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = wing
		weld.Parent = wing

		tagAppendage(wing, "Wing", i)
	end

	addVoidSmoke(body, cfg.CoreColor, 3)

	return body
end

local function buildBossModel(cfg: any, position: Vector3, model: Model, isMega: boolean): BasePart
	-- Dark void sphere body
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = cfg.Size
	body.Color = cfg.BodyColor
	body.Material = cfg.Material
	body.Transparency = 0.25
	body.Position = position
	body.Anchored = false
	body.CanCollide = true
	body.Parent = model

	-- Pulsing core
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Shape = Enum.PartType.Ball
	core.Size = cfg.Size * 0.3
	core.Color = cfg.CoreColor
	core.Material = Enum.Material.Neon
	core.Anchored = false
	core.CanCollide = false
	core.CastShadow = false
	core.Parent = model
	core.CFrame = body.CFrame

	local coreWeld = Instance.new("WeldConstraint")
	coreWeld.Part0 = body
	coreWeld.Part1 = core
	coreWeld.Parent = core

	tagAppendage(core, "BossCore", 1)

	-- Eyes (red, 6 for mega, 4 for regular)
	local eyeCount = isMega and 6 or 4
	for i = 1, eyeCount do
		local eye = Instance.new("Part")
		eye.Name = "Eye" .. i
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.one * (isMega and 0.8 or 0.6)
		eye.Color = cfg.EyeColor
		eye.Material = Enum.Material.Neon
		eye.Anchored = false
		eye.CanCollide = false
		eye.CastShadow = false
		eye.Parent = model

		local angle = (i / eyeCount) * math.pi * 2
		local r = cfg.Size.X * 0.4
		eye.CFrame = body.CFrame * CFrame.new(math.cos(angle) * r, math.sin(angle) * r * 0.3, -cfg.Size.Z / 2 - 0.3)

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = eye
		weld.Parent = eye
	end

	-- Long tendrils
	local tendrilCount = cfg.TendrilCount or 8
	for i = 1, tendrilCount do
		local len = 4 + math.random() * 4
		if isMega then
			len = 6 + math.random() * 6
		end
		local tendril = Instance.new("Part")
		tendril.Name = "Tendril" .. i
		tendril.Size = Vector3.new(0.3, len, 0.3)
		tendril.Color = cfg.BodyColor
		tendril.Material = Enum.Material.SmoothPlastic
		tendril.Transparency = 0.15
		tendril.Anchored = false
		tendril.CanCollide = false
		tendril.CastShadow = false
		tendril.Parent = model

		local angle = (i / tendrilCount) * math.pi * 2
		local r = cfg.Size.X * 0.35
		tendril.CFrame = body.CFrame * CFrame.new(math.cos(angle) * r, -cfg.Size.Y / 2 - len / 2, math.sin(angle) * r)

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = tendril
		weld.Parent = tendril

		tagAppendage(tendril, "Tendril", i)
	end

	-- Shell plates (mega boss only)
	if isMega then
		local shellCount = cfg.ShellPlates or 6
		for i = 1, shellCount do
			local plate = Instance.new("Part")
			plate.Name = "ShellPlate" .. i
			plate.Size = Vector3.new(3, 0.5, 4)
			plate.Color = Color3.fromRGB(25, 10, 40)
			plate.Material = Enum.Material.SmoothPlastic
			plate.Anchored = false
			plate.CanCollide = false
			plate.CastShadow = false
			plate.Transparency = 0.1
			plate.Parent = model

			local angle = (i / shellCount) * math.pi * 2
			local orbitR = cfg.Size.X * 0.6
			plate.CFrame = body.CFrame * CFrame.new(math.cos(angle) * orbitR, 0, math.sin(angle) * orbitR)

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = plate
			weld.Parent = plate

			tagAppendage(plate, "ShellPlate", i)
		end

		-- Dark aura sphere
		local aura = Instance.new("Part")
		aura.Name = "DarkAura"
		aura.Shape = Enum.PartType.Ball
		aura.Size = cfg.Size * 1.4
		aura.Color = Color3.fromRGB(10, 0, 15)
		aura.Material = Enum.Material.ForceField
		aura.Transparency = 0.7
		aura.Anchored = false
		aura.CanCollide = false
		aura.CastShadow = false
		aura.Parent = model
		aura.CFrame = body.CFrame

		local auraWeld = Instance.new("WeldConstraint")
		auraWeld.Part0 = body
		auraWeld.Part1 = aura
		auraWeld.Parent = aura

		-- Heavy void smoke + energy sparks
		addVoidSmoke(body, cfg.CoreColor, 20)

		local sparkEmitter = Instance.new("ParticleEmitter")
		sparkEmitter.Name = "EnergySparks"
		sparkEmitter.Color = ColorSequence.new(Color3.fromRGB(200, 160, 255))
		sparkEmitter.Size = NumberSequence.new(0.2, 0)
		sparkEmitter.Lifetime = NumberRange.new(0.2, 0.5)
		sparkEmitter.Rate = 15
		sparkEmitter.Speed = NumberRange.new(3, 8)
		sparkEmitter.SpreadAngle = Vector2.new(180, 180)
		sparkEmitter.LightEmission = 1
		sparkEmitter.Parent = body
	else
		addVoidSmoke(body, cfg.CoreColor, 12)
	end

	return body
end

local function buildWormSegmentModel(cfg: any, position: Vector3, segIndex: number, isHead: boolean): Model
	local segmentModel = Instance.new("Model")
	segmentModel.Name = "WormSegment"

	local typeVal = Instance.new("StringValue")
	typeVal.Name = "EnemyType"
	typeVal.Value = "Worm"
	typeVal.Parent = segmentModel

	-- Scale: head is full size, later segments shrink
	local scale = math.max(0.6, 1.0 - segIndex * 0.06)
	local size = cfg.Size * scale

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = size
	body.Color = cfg.BodyColor
	body.Material = cfg.Material
	body.Transparency = 0.2
	body.Position = position
	body.Anchored = false
	body.CanCollide = true
	body.Parent = segmentModel

	-- Segment core glow
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Shape = Enum.PartType.Ball
	core.Size = size * 0.35
	core.Color = cfg.CoreColor
	core.Material = Enum.Material.Neon
	core.Anchored = false
	core.CanCollide = false
	core.CastShadow = false
	core.Parent = segmentModel
	core.CFrame = body.CFrame

	local coreWeld = Instance.new("WeldConstraint")
	coreWeld.Part0 = body
	coreWeld.Part1 = core
	coreWeld.Parent = core

	-- Head gets eyes
	if isHead then
		for i = 1, 2 do
			local eye = Instance.new("Part")
			eye.Name = "Eye" .. i
			eye.Shape = Enum.PartType.Ball
			eye.Size = Vector3.one * 0.4
			eye.Color = cfg.EyeColor
			eye.Material = Enum.Material.Neon
			eye.Anchored = false
			eye.CanCollide = false
			eye.CastShadow = false
			eye.Parent = segmentModel

			local xOff = (i == 1) and -0.5 or 0.5
			eye.CFrame = body.CFrame * CFrame.new(xOff * scale, 0.2 * scale, -size.Z / 2 - 0.1)

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = eye
			weld.Parent = eye
		end
	end

	addVoidSmoke(body, cfg.CoreColor, 3)

	-- Body movers
	addBodyMovers(body, cfg.Speed, position)

	-- Health bar
	addHealthBar(segmentModel, body, size.Y / 2 + 1)

	segmentModel.PrimaryPart = body
	segmentModel.Parent = _enemyFolder

	return segmentModel
end

-------------------------------------------------
-- NEW ENEMY MODEL BUILDERS
-------------------------------------------------

local function buildSwarmlingModel(cfg: any, position: Vector3, model: Model): BasePart
	-- Small neon orb with trail
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = cfg.Size
	body.Color = cfg.CoreColor
	body.Material = Enum.Material.Neon
	body.Position = position
	body.Anchored = false
	body.CanCollide = false
	body.CastShadow = false
	body.Parent = model

	-- Trail for visibility while moving
	local att0 = Instance.new("Attachment")
	att0.Position = Vector3.new(0, 0, -cfg.Size.Z * 0.3)
	att0.Parent = body
	local att1 = Instance.new("Attachment")
	att1.Position = Vector3.new(0, 0, cfg.Size.Z * 0.3)
	att1.Parent = body
	local trail = Instance.new("Trail")
	trail.Attachment0 = att0
	trail.Attachment1 = att1
	trail.Lifetime = 0.2
	trail.MinLength = 0.1
	trail.Color = ColorSequence.new(cfg.CoreColor)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	trail.LightEmission = 0.5
	trail.Parent = body

	-- Point light for glow
	local light = Instance.new("PointLight")
	light.Color = cfg.CoreColor
	light.Brightness = 0.8
	light.Range = 4
	light.Shadows = false
	light.Parent = body

	addVoidSmoke(body, cfg.CoreColor, 3)

	return body
end

local function buildSpitterModel(cfg: any, position: Vector3, model: Model): BasePart
	-- Bulbous body with spit nozzle
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = cfg.Size
	body.Color = cfg.BodyColor
	body.Material = cfg.Material
	body.Position = position
	body.Anchored = false
	body.CanCollide = true
	body.Parent = model

	-- Bloated belly
	local belly = Instance.new("Part")
	belly.Name = "Belly"
	belly.Shape = Enum.PartType.Ball
	belly.Size = Vector3.new(cfg.Size.X * 0.8, cfg.Size.Y * 0.7, cfg.Size.Z * 0.8)
	belly.Color = cfg.CoreColor
	belly.Material = Enum.Material.Neon
	belly.Transparency = 0.3
	belly.Anchored = false
	belly.CanCollide = false
	belly.CastShadow = false
	belly.Parent = model
	belly.CFrame = body.CFrame * CFrame.new(0, -0.3, 0)

	local bellyWeld = Instance.new("WeldConstraint")
	bellyWeld.Part0 = body
	bellyWeld.Part1 = belly
	bellyWeld.Parent = belly

	-- Spit nozzle
	local nozzle = Instance.new("Part")
	nozzle.Name = "Nozzle"
	nozzle.Size = Vector3.new(0.6, 0.6, 1.5)
	nozzle.Color = cfg.CoreColor
	nozzle.Material = Enum.Material.Neon
	nozzle.Anchored = false
	nozzle.CanCollide = false
	nozzle.CastShadow = false
	nozzle.Parent = model
	nozzle.CFrame = body.CFrame * CFrame.new(0, 0.3, -cfg.Size.Z / 2 - 0.6)

	local nozzleWeld = Instance.new("WeldConstraint")
	nozzleWeld.Part0 = body
	nozzleWeld.Part1 = nozzle
	nozzleWeld.Parent = nozzle

	-- Eyes
	for i = 1, 2 do
		local eye = Instance.new("Part")
		eye.Name = "Eye" .. i
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.one * 0.5
		eye.Color = cfg.EyeColor
		eye.Material = Enum.Material.Neon
		eye.Anchored = false
		eye.CanCollide = false
		eye.CastShadow = false
		eye.Parent = model
		local xOff = (i == 1) and -0.8 or 0.8
		eye.CFrame = body.CFrame * CFrame.new(xOff, 0.5, -cfg.Size.Z / 2 - 0.2)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = eye
		weld.Parent = eye
	end

	addVoidSmoke(body, cfg.CoreColor, 4)

	return body
end

local function buildLurkerModel(cfg: any, position: Vector3, model: Model): BasePart
	-- Ghostly translucent body
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = cfg.Size
	body.Color = cfg.BodyColor
	body.Material = cfg.Material
	body.Transparency = 0.5
	body.Position = position
	body.Anchored = false
	body.CanCollide = true
	body.Parent = model

	-- Inner core
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Shape = Enum.PartType.Ball
	core.Size = cfg.Size * 0.4
	core.Color = cfg.CoreColor
	core.Material = Enum.Material.Neon
	core.Anchored = false
	core.CanCollide = false
	core.CastShadow = false
	core.Parent = model
	core.CFrame = body.CFrame

	local coreWeld = Instance.new("WeldConstraint")
	coreWeld.Part0 = body
	coreWeld.Part1 = core
	coreWeld.Parent = core

	-- Eyes
	for i = 1, 2 do
		local eye = Instance.new("Part")
		eye.Name = "Eye" .. i
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.one * 0.4
		eye.Color = cfg.EyeColor
		eye.Material = Enum.Material.Neon
		eye.Anchored = false
		eye.CanCollide = false
		eye.CastShadow = false
		eye.Parent = model
		local xOff = (i == 1) and -0.6 or 0.6
		eye.CFrame = body.CFrame * CFrame.new(xOff, 0.3, -cfg.Size.Z / 2 - 0.1)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = eye
		weld.Parent = eye
	end

	addVoidSmoke(body, cfg.CoreColor, 8)

	return body
end

local function buildCrystalbackModel(cfg: any, position: Vector3, model: Model): BasePart
	-- Heavy armored body
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = cfg.Size
	body.Color = cfg.BodyColor
	body.Material = cfg.Material
	body.Position = position
	body.Anchored = false
	body.CanCollide = true
	body.Parent = model

	-- Crystal shell plates on front
	for i = 1, 3 do
		local plate = Instance.new("Part")
		plate.Name = "Shell" .. i
		plate.Size = Vector3.new(cfg.Size.X * 0.35, cfg.Size.Y * 0.6, 0.4)
		plate.Color = cfg.ShellColor
		plate.Material = Enum.Material.Glass
		plate.Transparency = 0.3
		plate.Anchored = false
		plate.CanCollide = false
		plate.CastShadow = false
		plate.Parent = model

		local xOff = (i - 2) * (cfg.Size.X * 0.3)
		plate.CFrame = body.CFrame * CFrame.new(xOff, cfg.Size.Y * 0.1, -cfg.Size.Z / 2 - 0.15)
		tagAppendage(plate, "Shell", i)

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = plate
		weld.Parent = plate
	end

	-- 4 stubby legs
	for i = 1, 4 do
		local leg = Instance.new("Part")
		leg.Name = "Leg" .. i
		leg.Size = Vector3.new(0.8, 2, 0.8)
		leg.Color = cfg.BodyColor
		leg.Material = cfg.Material
		leg.Anchored = false
		leg.CanCollide = false
		leg.CastShadow = false
		leg.Parent = model

		local side = (i <= 2) and -1 or 1
		local zOff = ((i - 1) % 2 == 0) and cfg.Size.Z * 0.25 or -cfg.Size.Z * 0.25
		leg.CFrame = body.CFrame * CFrame.new(side * cfg.Size.X / 2, -cfg.Size.Y / 2 - 0.5, zOff)
		tagAppendage(leg, "Leg", i)

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = leg
		weld.Parent = leg
	end

	-- Eyes
	for i = 1, 2 do
		local eye = Instance.new("Part")
		eye.Name = "Eye" .. i
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.one * 0.6
		eye.Color = cfg.EyeColor
		eye.Material = Enum.Material.Neon
		eye.Anchored = false
		eye.CanCollide = false
		eye.CastShadow = false
		eye.Parent = model
		local xOff = (i == 1) and -1.0 or 1.0
		eye.CFrame = body.CFrame * CFrame.new(xOff, cfg.Size.Y * 0.2, -cfg.Size.Z / 2 - 0.2)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = eye
		weld.Parent = eye
	end

	return body
end

local function buildBroodmotherModel(cfg: any, position: Vector3, model: Model): BasePart
	-- Large bloated body
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = cfg.Size
	body.Color = cfg.BodyColor
	body.Material = cfg.Material
	body.Position = position
	body.Anchored = false
	body.CanCollide = true
	body.Parent = model

	-- Egg sacs (pulsing neon blobs)
	for i = 1, 4 do
		local sac = Instance.new("Part")
		sac.Name = "EggSac" .. i
		sac.Shape = Enum.PartType.Ball
		sac.Size = Vector3.one * 1.2
		sac.Color = cfg.CoreColor
		sac.Material = Enum.Material.Neon
		sac.Transparency = 0.3
		sac.Anchored = false
		sac.CanCollide = false
		sac.CastShadow = false
		sac.Parent = model

		local angle = (i / 4) * math.pi * 2
		local r = cfg.Size.X * 0.35
		sac.CFrame = body.CFrame * CFrame.new(math.cos(angle) * r, -cfg.Size.Y * 0.2, math.sin(angle) * r)
		tagAppendage(sac, "EggSac", i)

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = sac
		weld.Parent = sac
	end

	-- Eyes (4 red eyes)
	for i = 1, 4 do
		local eye = Instance.new("Part")
		eye.Name = "Eye" .. i
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.one * 0.4
		eye.Color = cfg.EyeColor
		eye.Material = Enum.Material.Neon
		eye.Anchored = false
		eye.CanCollide = false
		eye.CastShadow = false
		eye.Parent = model
		local xOff = ((i - 1) % 2 == 0) and -0.6 or 0.6
		local yOff = (i <= 2) and 0.5 or 0.1
		eye.CFrame = body.CFrame * CFrame.new(xOff, yOff, -cfg.Size.Z / 2 - 0.2)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = eye
		weld.Parent = eye
	end

	addVoidSmoke(body, cfg.CoreColor, 5)

	return body
end

local function buildLeechModel(cfg: any, position: Vector3, model: Model): BasePart
	-- Flat slug-like body
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = cfg.Size
	body.Color = cfg.BodyColor
	body.Material = cfg.Material
	body.Position = position
	body.Anchored = false
	body.CanCollide = true
	body.Parent = model

	-- Red mouth/sucker at front
	local mouth = Instance.new("Part")
	mouth.Name = "Mouth"
	mouth.Shape = Enum.PartType.Cylinder
	mouth.Size = Vector3.new(0.3, cfg.Size.X * 0.6, cfg.Size.X * 0.6)
	mouth.Color = cfg.CoreColor
	mouth.Material = Enum.Material.Neon
	mouth.Anchored = false
	mouth.CanCollide = false
	mouth.CastShadow = false
	mouth.Parent = model
	mouth.CFrame = body.CFrame * CFrame.new(0, 0, -cfg.Size.Z / 2 - 0.1) * CFrame.Angles(0, 0, math.rad(90))

	local mouthWeld = Instance.new("WeldConstraint")
	mouthWeld.Part0 = body
	mouthWeld.Part1 = mouth
	mouthWeld.Parent = mouth

	-- Tail segments
	for i = 1, 2 do
		local seg = Instance.new("Part")
		seg.Name = "Tail" .. i
		seg.Size = Vector3.new(cfg.Size.X * (1 - i * 0.2), cfg.Size.Y, cfg.Size.Z * 0.3)
		seg.Color = cfg.BodyColor
		seg.Material = cfg.Material
		seg.Anchored = false
		seg.CanCollide = false
		seg.CastShadow = false
		seg.Parent = model
		seg.CFrame = body.CFrame * CFrame.new(0, 0, cfg.Size.Z / 2 + i * cfg.Size.Z * 0.25)
		tagAppendage(seg, "Tail", i)

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = seg
		weld.Parent = seg
	end

	return body
end

local function buildHivemindModel(cfg: any, position: Vector3, model: Model): BasePart
	-- Pulsing glass orb with gold core
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = cfg.Size
	body.Color = cfg.BodyColor
	body.Material = cfg.Material
	body.Transparency = 0.4
	body.Position = position
	body.Anchored = false
	body.CanCollide = true
	body.Parent = model

	-- Golden core
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Shape = Enum.PartType.Ball
	core.Size = cfg.Size * 0.4
	core.Color = cfg.CoreColor
	core.Material = Enum.Material.Neon
	core.Anchored = false
	core.CanCollide = false
	core.CastShadow = false
	core.Parent = model
	core.CFrame = body.CFrame

	local coreWeld = Instance.new("WeldConstraint")
	coreWeld.Part0 = body
	coreWeld.Part1 = core
	coreWeld.Parent = core

	-- Orbiting runes (small neon cubes)
	for i = 1, 4 do
		local rune = Instance.new("Part")
		rune.Name = "Rune" .. i
		rune.Size = Vector3.one * 0.5
		rune.Color = cfg.CoreColor
		rune.Material = Enum.Material.Neon
		rune.Anchored = false
		rune.CanCollide = false
		rune.CastShadow = false
		rune.Parent = model

		local angle = (i / 4) * math.pi * 2
		local r = cfg.Size.X * 0.6
		rune.CFrame = body.CFrame * CFrame.new(math.cos(angle) * r, 0, math.sin(angle) * r)
		tagAppendage(rune, "Rune", i)

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = rune
		weld.Parent = rune
	end

	addVoidSmoke(body, cfg.CoreColor, 6)

	return body
end

local function buildBurrowerModel(cfg: any, position: Vector3, model: Model): BasePart
	-- Elongated body
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = cfg.Size
	body.Color = cfg.BodyColor
	body.Material = cfg.Material
	body.Position = position
	body.Anchored = false
	body.CanCollide = true
	body.Parent = model

	-- Drill nose
	local drill = Instance.new("Part")
	drill.Name = "Drill"
	drill.Shape = Enum.PartType.Ball
	drill.Size = Vector3.new(cfg.Size.X * 0.6, cfg.Size.Y * 0.6, cfg.Size.X * 0.6)
	drill.Color = cfg.CoreColor
	drill.Material = Enum.Material.Neon
	drill.Anchored = false
	drill.CanCollide = false
	drill.CastShadow = false
	drill.Parent = model
	drill.CFrame = body.CFrame * CFrame.new(0, 0, -cfg.Size.Z / 2 - cfg.Size.X * 0.2)

	local drillWeld = Instance.new("WeldConstraint")
	drillWeld.Part0 = body
	drillWeld.Part1 = drill
	drillWeld.Parent = drill

	-- Ridged segments on body
	for i = 1, 3 do
		local ridge = Instance.new("Part")
		ridge.Name = "Ridge" .. i
		ridge.Size = Vector3.new(cfg.Size.X * 1.1, cfg.Size.Y * 0.3, 0.3)
		ridge.Color = cfg.CoreColor
		ridge.Material = Enum.Material.Neon
		ridge.Transparency = 0.4
		ridge.Anchored = false
		ridge.CanCollide = false
		ridge.CastShadow = false
		ridge.Parent = model

		local zOff = (i - 2) * (cfg.Size.Z * 0.3)
		ridge.CFrame = body.CFrame * CFrame.new(0, cfg.Size.Y * 0.3, zOff)
		tagAppendage(ridge, "Ridge", i)

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = ridge
		weld.Parent = ridge
	end

	-- Eyes
	for i = 1, 2 do
		local eye = Instance.new("Part")
		eye.Name = "Eye" .. i
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.one * 0.4
		eye.Color = cfg.EyeColor
		eye.Material = Enum.Material.Neon
		eye.Anchored = false
		eye.CanCollide = false
		eye.CastShadow = false
		eye.Parent = model
		local xOff = (i == 1) and -0.5 or 0.5
		eye.CFrame = body.CFrame * CFrame.new(xOff, 0.3, -cfg.Size.Z / 2 - 0.1)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = eye
		weld.Parent = eye
	end

	return body
end

local function buildVoidWraithModel(cfg: any, position: Vector3, model: Model): BasePart
	-- Tall ghostly figure
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = cfg.Size
	body.Color = cfg.BodyColor
	body.Material = cfg.Material
	body.Transparency = 0.3
	body.Position = position
	body.Anchored = false
	body.CanCollide = true
	body.Parent = model

	-- Core
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Shape = Enum.PartType.Ball
	core.Size = cfg.Size * 0.3
	core.Color = cfg.CoreColor
	core.Material = Enum.Material.Neon
	core.Anchored = false
	core.CanCollide = false
	core.CastShadow = false
	core.Parent = model
	core.CFrame = body.CFrame

	local coreWeld = Instance.new("WeldConstraint")
	coreWeld.Part0 = body
	coreWeld.Part1 = core
	coreWeld.Parent = core

	-- Wispy tendrils (3 hanging from bottom)
	for i = 1, 3 do
		local tendril = Instance.new("Part")
		tendril.Name = "Tendril" .. i
		tendril.Size = Vector3.new(0.3, 3, 0.3)
		tendril.Color = cfg.CoreColor
		tendril.Material = Enum.Material.Neon
		tendril.Transparency = 0.5
		tendril.Anchored = false
		tendril.CanCollide = false
		tendril.CastShadow = false
		tendril.Parent = model

		local angle = (i / 3) * math.pi * 2
		local r = cfg.Size.X * 0.25
		tendril.CFrame = body.CFrame
			* CFrame.new(math.cos(angle) * r, -cfg.Size.Y / 2 - tendril.Size.Y / 2, math.sin(angle) * r)
		tagAppendage(tendril, "Tendril", i)

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = tendril
		weld.Parent = tendril
	end

	-- Eyes (ghostly)
	for i = 1, 2 do
		local eye = Instance.new("Part")
		eye.Name = "Eye" .. i
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.one * 0.5
		eye.Color = cfg.EyeColor
		eye.Material = Enum.Material.Neon
		eye.Anchored = false
		eye.CanCollide = false
		eye.CastShadow = false
		eye.Parent = model
		local xOff = (i == 1) and -0.5 or 0.5
		eye.CFrame = body.CFrame * CFrame.new(xOff, cfg.Size.Y * 0.2, -cfg.Size.Z / 2 - 0.1)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = eye
		weld.Parent = eye
	end

	addVoidSmoke(body, cfg.CoreColor, 10)

	return body
end

-------------------------------------------------
-- CREATE ENEMY MODEL (dispatches to type-specific builder)
-------------------------------------------------

function EnemyService:_createEnemyModel(enemyType: string, position: Vector3): Model
	local cfg = (GameConfig.Enemies.Types :: any)[enemyType]
	if not cfg then
		error("Unknown enemy type: " .. enemyType)
	end

	local model = Instance.new("Model")
	model.Name = enemyType

	-- Add EnemyType StringValue for client-side animation detection
	local typeVal = Instance.new("StringValue")
	typeVal.Name = "EnemyType"
	typeVal.Value = enemyType
	typeVal.Parent = model

	local body: BasePart

	if enemyType == "Drone" or enemyType == "Brute" or enemyType == "Dasher" then
		body = buildDroneModel(cfg, position, model)
	elseif enemyType == "Skitter" then
		body = buildSkitterModel(cfg, position, model)
	elseif enemyType == "Behemoth" then
		body = buildBehemothModel(cfg, position, model)
	elseif enemyType == "Shade" then
		body = buildShadeModel(cfg, position, model)
	elseif
		enemyType == "MegaBoss"
		or enemyType == "Boss"
		or enemyType == "BroodQueen"
		or enemyType == "PhantomWeaver"
		or enemyType == "AbyssalSerpent"
		or enemyType == "VoidArchitect"
	then
		body = buildBossModel(cfg, position, model, enemyType == "MegaBoss")
	elseif enemyType == "Swarmling" then
		body = buildSwarmlingModel(cfg, position, model)
	elseif enemyType == "Spitter" then
		body = buildSpitterModel(cfg, position, model)
	elseif enemyType == "Lurker" then
		body = buildLurkerModel(cfg, position, model)
	elseif enemyType == "Crystalback" then
		body = buildCrystalbackModel(cfg, position, model)
	elseif enemyType == "Broodmother" then
		body = buildBroodmotherModel(cfg, position, model)
	elseif enemyType == "Leech" then
		body = buildLeechModel(cfg, position, model)
	elseif enemyType == "Hivemind" then
		body = buildHivemindModel(cfg, position, model)
	elseif enemyType == "Burrower" then
		body = buildBurrowerModel(cfg, position, model)
	elseif enemyType == "VoidWraith" then
		body = buildVoidWraithModel(cfg, position, model)
	else
		-- Fallback: generic body
		local fallbackBody = Instance.new("Part")
		fallbackBody.Name = "Body"
		fallbackBody.Size = cfg.Size
		fallbackBody.Color = cfg.BodyColor or Color3.fromRGB(25, 15, 40)
		fallbackBody.Material = Enum.Material.SmoothPlastic
		fallbackBody.Position = position
		fallbackBody.Anchored = false
		fallbackBody.CanCollide = true
		fallbackBody.Parent = model
		body = fallbackBody
	end

	-- Body movers for AI movement
	addBodyMovers(body, cfg.Speed, position)

	-- Health bar
	addHealthBar(model, body, cfg.Size.Y / 2 + 1.5)

	model.PrimaryPart = body
	model.Parent = _enemyFolder

	return model
end

function EnemyService:SpawnEnemy(enemyType: string, position: Vector3): EnemyData
	local cfg = (GameConfig.Enemies.Types :: any)[enemyType]
	local wave = GameService:GetCurrentWave()
	local waveCfg = GameConfig.Waves

	-- Scale stats by wave
	local healthMult = 1 + (wave - 1) * waveCfg.HealthScaling
	local damageMult = 1 + (wave - 1) * waveCfg.DamageScaling
	local speedMult = 1 + (wave - 1) * waveCfg.SpeedScaling

	-- Player-count scaling for HP
	local playerCount = GameService:GetPlayerCount()
	local scalingCfg = GameConfig.Scaling
	if BOSS_TYPES[enemyType] then
		healthMult *= 1.0 + scalingCfg.BossHealthPerPlayer * (playerCount - 1)
	else
		healthMult *= 1.0 + scalingCfg.EnemyHealthPerPlayer * (playerCount - 1)
	end

	local model = self:_createEnemyModel(enemyType, position)

	local enemyData: EnemyData = {
		Model = model,
		Type = enemyType,
		Health = math.floor(cfg.Health * healthMult),
		MaxHealth = math.floor(cfg.Health * healthMult),
		Speed = cfg.Speed * speedMult,
		Damage = math.floor(cfg.Damage * damageMult),
		AttackRange = cfg.AttackRange,
		AttackCooldown = cfg.AttackCooldown,
		XPValue = cfg.XPValue,
		LastAttackTime = 0,
		Target = nil,
		Alive = true,
	}

	-- Shade: start in CIRCLE state
	if enemyType == "Shade" then
		enemyData.ShadeState = "CIRCLE"
	end

	-- Spitter: init spit timer
	if enemyType == "Spitter" then
		enemyData.LastSpitTime = 0
	end

	-- Lurker: start visible
	if enemyType == "Lurker" then
		enemyData.TeleportPhase = "VISIBLE"
		enemyData.LastTeleportTime = tick()
	end

	-- Broodmother: init spawn timer
	if enemyType == "Broodmother" then
		enemyData.LastSpawnTime = 0
	end

	-- Burrower: start surfaced
	if enemyType == "Burrower" then
		local burrowerCfg = (GameConfig.Enemies.Types :: any).Burrower
		enemyData.BurrowState = "SURFACED"
		enemyData.BurrowStateUntil = tick() + burrowerCfg.SurfaceDuration
	end

	-- VoidWraith: start solid
	if enemyType == "VoidWraith" then
		local wrCfg = (GameConfig.Enemies.Types :: any).VoidWraith
		enemyData.PhaseState = "SOLID"
		enemyData.PhaseStateUntil = tick() + wrCfg.PhaseInterval
	end

	-- MegaBoss: init attack timers
	if enemyType == "MegaBoss" then
		local now = tick()
		enemyData.BossState = "CHASE"
		enemyData.LastVoidBolt = now
		enemyData.LastSlam = now
		enemyData.LastSpawnMinions = now
		enemyData.LastVoidPull = now
	end

	-- BroodQueen: init timers
	if enemyType == "BroodQueen" then
		local now = tick()
		enemyData.BossState = "CHASE"
		enemyData.LastSpawnTime = now
		enemyData.LastPoisonPuddle = now
	end

	-- PhantomWeaver: init timers
	if enemyType == "PhantomWeaver" then
		local now = tick()
		enemyData.BossState = "CHASE"
		enemyData.LastTeleportTime = now
		enemyData.TeleportPhase = "VISIBLE"
		enemyData.LastShadowBolt = now
		enemyData.LastCloneSpawn = now
	end

	-- AbyssalSerpent: init timers
	if enemyType == "AbyssalSerpent" then
		local now = tick()
		enemyData.BossState = "CHASE"
		enemyData.ChargeState = "IDLE"
		enemyData.LastCharge = now
		enemyData.LastTailSweep = now
		enemyData.LastAcidSpit = now
	end

	-- VoidArchitect: init timers
	if enemyType == "VoidArchitect" then
		local now = tick()
		enemyData.BossState = "CHASE"
		enemyData.LaserState = "IDLE"
		enemyData.LastLaser = now
		enemyData.LastBarrier = now
		enemyData.LastSummon = now
	end

	-- Update AlignPosition max velocity with scaled speed
	local body = model.PrimaryPart
	if body then
		local align = body:FindFirstChildOfClass("AlignPosition")
		if align then
			(align :: AlignPosition).MaxVelocity = enemyData.Speed
		end
	end

	table.insert(_enemies, enemyData)
	return enemyData
end

function EnemyService:DamageEnemy(enemy: EnemyData, damage: number, attacker: Player?)
	if not enemy.Alive then
		return
	end

	-- Shade: invulnerable during ascent
	if enemy.ShadeState == "ASCEND" then
		return
	end

	-- VoidWraith: immune when phased
	if enemy.PhaseState == "PHASED" then
		return
	end

	-- Burrower: immune when underground
	if enemy.BurrowState == "BURROWED" then
		return
	end

	-- CriticalStrike relic: chance to deal double damage
	if attacker and StatsService then
		local critTier = StatsService:GetRelicLevels(attacker)["CriticalStrike"] or 0
		if critTier > 0 and math.random() < critTier * 0.05 then
			damage *= 2
		end
	end

	-- Crystalback: front armor damage reduction
	if enemy.Type == "Crystalback" then
		local crystalCfg = (GameConfig.Enemies.Types :: any).Crystalback
		local body = enemy.Model.PrimaryPart
		if body then
			-- Check if damage source is in front (use facing direction)
			-- Approximate: reduce damage by front armor factor always
			-- (full directional check would need attacker position)
			damage = math.floor(damage * (1 - crystalCfg.FrontArmorReduction))
			if damage < 1 then
				damage = 1
			end
		end
	end

	enemy.Health -= damage

	-- Notify clients for VFX
	local pos = Vector3.zero
	if enemy.Model.PrimaryPart then
		pos = enemy.Model.PrimaryPart.Position
	end
	self.Client.EnemyDamaged:FireAll(enemy.Model, damage, pos)

	-- Update health bar
	self:_updateHealthBar(enemy)

	-- Boss health bar update
	if BOSS_TYPES[enemy.Type] then
		local pct = math.clamp(enemy.Health / enemy.MaxHealth, 0, 1)
		local isEnraged = _enraged
		self.Client.BossHealthUpdate:FireAll(pct, isEnraged)
	end

	if enemy.Health <= 0 then
		self:_killEnemy(enemy, attacker)
	end
end

function EnemyService:_updateHealthBar(enemy: EnemyData)
	if not enemy.Model then
		return
	end
	local billboard = enemy.Model:FindFirstChild("HealthBar") :: BillboardGui?
	if not billboard then
		return
	end
	local bg = billboard:FindFirstChild("Background")
	if not bg then
		return
	end
	local fill = bg:FindFirstChild("Fill") :: Frame?
	if fill then
		local pct = math.clamp(enemy.Health / enemy.MaxHealth, 0, 1)
		fill.Size = UDim2.new(pct, 0, 1, 0)
	end
end

function EnemyService:_killEnemy(enemy: EnemyData, killer: Player?)
	enemy.Alive = false
	enemy.Health = 0

	-- Drop XP gem at death position
	local deathPos = Vector3.zero
	if enemy.Model.PrimaryPart then
		deathPos = enemy.Model.PrimaryPart.Position
	end

	self.Client.EnemyKilled:FireAll(enemy.Model, enemy.Type)
	self.EnemyKilled:Fire(enemy, killer)

	-- Spawn XP gem
	GameService:SpawnXPGem(deathPos, enemy.XPValue)

	-- ExplosiveFinish relic: enemies explode on death
	if killer and StatsService then
		local explosive = StatsService:GetRelicLevels(killer)["ExplosiveFinish"] or 0
		if explosive > 0 then
			local explosionDamage = explosive * 5
			local explosionRadius = 5
			for _, other in _enemies do
				if other ~= enemy and other.Alive and other.Model and other.Model.PrimaryPart then
					if (other.Model.PrimaryPart.Position - deathPos).Magnitude <= explosionRadius then
						self:DamageEnemy(other, explosionDamage, killer)
					end
				end
			end
		end
	end

	-- Check if mega-boss was killed
	if enemy.Type == "MegaBoss" then
		_megaBossEnemy = nil
		GameService:MegaBossKilled()
	end

	-- Reset enrage when any periodic boss dies
	if BOSS_TYPES[enemy.Type] and enemy.Type ~= "MegaBoss" then
		_enraged = false
	end

	GameService:EnemyKilled(killer)

	-- Worm splitting: if this is a worm segment, split the worm
	if enemy.Type == "Worm" and enemy.WormId then
		local worm = self:_getWormData(enemy.WormId)
		if worm and worm.Alive then
			-- Find this segment's position in the worm
			local segIdx = nil
			for i, seg in worm.Segments do
				if seg == enemy then
					segIdx = i
					break
				end
			end
			if segIdx then
				local isHead = (segIdx == 1)
				local isTail = (segIdx == #worm.Segments)

				if isHead then
					-- Head dies: remove from front, next segment becomes head
					table.remove(worm.Segments, 1)
					if #worm.Segments == 0 then
						worm.Alive = false
					end
				elseif isTail then
					-- Tail dies: just remove
					table.remove(worm.Segments, segIdx)
					if #worm.Segments == 0 then
						worm.Alive = false
					end
				else
					-- Middle segment: split into two worms
					self:_splitWorm(worm, segIdx)
				end
			end
		end
	end

	-- Destroy model
	task.delay(0.1, function()
		if enemy.Model and enemy.Model.Parent then
			enemy.Model:Destroy()
		end
	end)

	-- Remove from list
	local idx = table.find(_enemies, enemy)
	if idx then
		table.remove(_enemies, idx)
	end
end

function EnemyService:_findClosestPlayer(position: Vector3): (Player?, number)
	local closestPlayer: Player? = nil
	local closestDist = math.huge

	for _, player in Players:GetPlayers() do
		local stats = GameService:GetPlayerStats(player)
		if stats and stats.Health > 0 then
			local char = player.Character
			if char then
				local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					local dist = (root.Position - position).Magnitude
					if dist < closestDist then
						closestDist = dist
						closestPlayer = player
					end
				end
			end
		end
	end

	return closestPlayer, closestDist
end

-------------------------------------------------
-- SHADE AI
-------------------------------------------------

function EnemyService:_updateShade(enemy: EnemyData, dt: number, now: number)
	local body = enemy.Model.PrimaryPart
	if not body then
		return
	end

	local cfg = (GameConfig.Enemies.Types :: any).Shade
	local pos = body.Position
	local target, dist = self:_findClosestPlayer(pos)
	enemy.Target = target

	if not target then
		return
	end

	local char = target.Character
	if not char then
		return
	end
	local targetRoot = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRoot then
		return
	end

	local targetPos = targetRoot.Position
	local align = body:FindFirstChildOfClass("AlignPosition") :: AlignPosition?
	local alignOrient = body:FindFirstChildOfClass("AlignOrientation") :: AlignOrientation?

	local hoverY = cfg.HoverHeight or 9
	-- Bob effect
	local bob = math.sin(now * 2.5) * 1.0

	if enemy.ShadeState == "ASCEND" then
		-- Flying back up after dive
		if align then
			align.MaxVelocity = enemy.Speed * 1.5
			align.Position = Vector3.new(pos.X, hoverY + bob, pos.Z)
		end
		if enemy.AscendUntil and now >= enemy.AscendUntil then
			enemy.ShadeState = "CIRCLE"
			enemy.AscendUntil = nil
			if align then
				align.MaxVelocity = enemy.Speed
			end
		end
	elseif enemy.ShadeState == "DIVE" then
		-- Diving toward target
		if align then
			align.MaxVelocity = enemy.Speed * (cfg.DiveSpeedMult or 2.0)
			if enemy.DiveTarget then
				align.Position = enemy.DiveTarget
			end
		end

		-- Check if reached ground level or close to target
		local horizontalDist = ((Vector3.new(pos.X, 0, pos.Z)) - Vector3.new(targetPos.X, 0, targetPos.Z)).Magnitude
		if pos.Y <= 3 or horizontalDist < enemy.AttackRange then
			-- Deal damage if close
			if horizontalDist < enemy.AttackRange + 2 then
				GameService:DamagePlayer(target, enemy.Damage)
			end
			-- Ascend
			enemy.ShadeState = "ASCEND"
			enemy.AscendUntil = now + 0.5
			enemy.DiveTarget = nil
		end
	else
		-- CIRCLE state: orbit around target at distance
		local circleRadius = cfg.CircleDistance or 17
		local horizontalDist = ((Vector3.new(pos.X, 0, pos.Z)) - Vector3.new(targetPos.X, 0, targetPos.Z)).Magnitude

		-- Circle movement: move perpendicular + adjust distance
		local toTarget = Vector3.new(targetPos.X - pos.X, 0, targetPos.Z - pos.Z)
		if toTarget.Magnitude > 0.1 then
			local forward = toTarget.Unit
			local lateral = Vector3.new(-forward.Z, 0, forward.X)
			local distAdjust = (horizontalDist - circleRadius) * 0.3
			local moveDir = lateral + forward * math.clamp(distAdjust, -1, 1)
			if moveDir.Magnitude > 0.1 then
				moveDir = moveDir.Unit
			end

			if align then
				local moveTarget = pos + moveDir * enemy.Speed * dt * 10
				align.Position = Vector3.new(moveTarget.X, hoverY + bob, moveTarget.Z)
			end
		end

		-- Face target
		local flatDir = Vector3.new(targetPos.X - pos.X, 0, targetPos.Z - pos.Z)
		if alignOrient and flatDir.Magnitude > 0.1 then
			alignOrient.CFrame = CFrame.lookAt(Vector3.zero, flatDir.Unit)
		end

		-- Check if should dive
		if (now - enemy.LastAttackTime) >= enemy.AttackCooldown and dist < 30 then
			enemy.ShadeState = "DIVE"
			enemy.LastAttackTime = now
			enemy.DiveTarget = targetPos + Vector3.new(0, 1, 0)
		end
	end
end

-------------------------------------------------
-- BOSS AI
-------------------------------------------------

function EnemyService:_updateBossAI(enemy: EnemyData, _dt: number, now: number)
	if enemy.Type ~= "MegaBoss" or not enemy.Alive then
		return
	end

	local body = enemy.Model and enemy.Model.PrimaryPart
	if not body then
		return
	end

	local cfg = (GameConfig.Enemies.Types :: any).MegaBoss
	local pos = body.Position

	-- Check enrage
	if not _enraged and enemy.Health / enemy.MaxHealth <= cfg.EnrageThreshold then
		_enraged = true
		-- Boost stats on enrage
		enemy.Damage = math.floor(enemy.Damage * 2)
		enemy.Speed *= 1.5
		local align = body:FindFirstChildOfClass("AlignPosition") :: AlignPosition?
		if align then
			align.MaxVelocity = enemy.Speed
		end
	end

	-- State machine: don't overlap attacks
	if enemy.BossStateUntil and now < enemy.BossStateUntil then
		-- In middle of an attack, handle ongoing effects
		if enemy.BossState == "PULL" and enemy.VoidPullUntil and now < enemy.VoidPullUntil then
			-- Pull players toward boss
			for _, player in Players:GetPlayers() do
				local stats = GameService:GetPlayerStats(player)
				if stats and stats.Health > 0 then
					local char = player.Character
					if char then
						local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
						if root then
							local towardBoss = (pos - root.Position).Unit * cfg.VoidPullSpeed
							root.AssemblyLinearVelocity += Vector3.new(towardBoss.X, 0, towardBoss.Z)
						end
					end
				end
			end
		end
		return
	end

	-- Reset state
	enemy.BossState = "CHASE"

	-- Priority: Void Pull (enrage only) > Tendril Slam > Spawn Minions > Void Bolt
	if _enraged and now - (enemy.LastVoidPull or 0) >= cfg.VoidPullInterval then
		enemy.BossState = "PULL"
		enemy.LastVoidPull = now
		enemy.BossStateUntil = now + cfg.VoidPullDuration
		enemy.VoidPullUntil = now + cfg.VoidPullDuration
		self.Client.VoidPullStarted:FireAll(pos, cfg.VoidPullDuration)
		return
	end

	if now - (enemy.LastSlam or 0) >= cfg.TendrilSlamInterval then
		enemy.BossState = "SLAM"
		enemy.LastSlam = now
		enemy.BossStateUntil = now + cfg.TendrilSlamTelegraph + 0.3

		-- Telegraph then damage
		self.Client.TendrilSlam:FireAll(pos, cfg.TendrilSlamRadius)
		task.delay(cfg.TendrilSlamTelegraph, function()
			if not enemy.Alive then
				return
			end
			-- Damage all players in radius
			for _, player in Players:GetPlayers() do
				local stats = GameService:GetPlayerStats(player)
				if stats and stats.Health > 0 then
					local char = player.Character
					if char then
						local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
						if root and (root.Position - pos).Magnitude <= cfg.TendrilSlamRadius then
							GameService:DamagePlayer(player, cfg.TendrilSlamDamage)
						end
					end
				end
			end
		end)
		return
	end

	if now - (enemy.LastSpawnMinions or 0) >= cfg.SpawnMinionsInterval then
		enemy.BossState = "SPAWN"
		enemy.LastSpawnMinions = now
		enemy.BossStateUntil = now + 1.0

		-- Spawn drones from body
		local spawnCount = math.min(cfg.SpawnMinionsCount, GameService:GetMaxConcurrentEnemies() - #_enemies)
		for i = 1, spawnCount do
			local angle = (i / spawnCount) * math.pi * 2
			local spawnPos = pos + Vector3.new(math.cos(angle) * 8, 0, math.sin(angle) * 8)
			self:SpawnEnemy("Drone", spawnPos)
		end
		return
	end

	if now - (enemy.LastVoidBolt or 0) >= cfg.VoidBoltInterval then
		enemy.LastVoidBolt = now

		-- Fire void bolt at closest player
		local target = self:_findClosestPlayer(pos)
		if target then
			local char = target.Character
			if char then
				local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					local dir = (root.Position - pos).Unit
					self:_fireVoidBolt(pos, dir, cfg)
				end
			end
		end
	end
end

-------------------------------------------------
-- BROOD QUEEN AI
-------------------------------------------------
function EnemyService:_updateBroodQueenAI(enemy: EnemyData, _dt: number, now: number)
	if not enemy.Alive then
		return
	end

	local body = enemy.Model and enemy.Model.PrimaryPart
	if not body then
		return
	end

	local cfg = (GameConfig.Enemies.Types :: any).BroodQueen
	local pos = body.Position

	-- Enrage check
	if not _enraged and enemy.Health / enemy.MaxHealth <= cfg.EnrageThreshold then
		_enraged = true
		enemy.Damage = math.floor(enemy.Damage * 1.5)
		enemy.Speed *= 1.3
		local align = body:FindFirstChildOfClass("AlignPosition") :: AlignPosition?
		if align then
			align.MaxVelocity = enemy.Speed
		end
	end

	-- State machine
	if enemy.BossStateUntil and now < enemy.BossStateUntil then
		return
	end
	enemy.BossState = "CHASE"

	-- Spawn swarmlings
	if now - (enemy.LastSpawnTime or 0) >= cfg.SpawnInterval then
		enemy.BossState = "SPAWN"
		enemy.LastSpawnTime = now
		enemy.BossStateUntil = now + 1.0

		local spawnCount = math.min(cfg.SpawnCount, GameService:GetMaxConcurrentEnemies() - #_enemies)
		for i = 1, spawnCount do
			local angle = (i / spawnCount) * math.pi * 2
			local spawnPos = pos + Vector3.new(math.cos(angle) * 6, 0, math.sin(angle) * 6)
			self:SpawnEnemy("Swarmling", spawnPos)
		end
		return
	end

	-- Poison puddle
	if now - (enemy.LastPoisonPuddle or 0) >= cfg.PoisonPuddleInterval then
		enemy.LastPoisonPuddle = now
		enemy.BossStateUntil = now + 0.5

		local target = self:_findClosestPlayer(pos)
		if target then
			local char = target.Character
			if char then
				local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					local puddlePos = root.Position
					self.Client.PoisonPuddlePlaced:FireAll(puddlePos, cfg.PoisonPuddleRadius, cfg.PoisonPuddleDuration)
					-- Damage over time in puddle area
					task.spawn(function()
						local elapsed = 0
						while elapsed < cfg.PoisonPuddleDuration do
							local dt2 = task.wait(1)
							elapsed += dt2
							for _, player in Players:GetPlayers() do
								local stats = GameService:GetPlayerStats(player)
								if stats and stats.Health > 0 then
									local pChar = player.Character
									if pChar then
										local pRoot = pChar:FindFirstChild("HumanoidRootPart") :: BasePart?
										if
											pRoot
											and (pRoot.Position - puddlePos).Magnitude <= cfg.PoisonPuddleRadius
										then
											GameService:DamagePlayer(player, cfg.PoisonPuddleDamage)
										end
									end
								end
							end
						end
					end)
				end
			end
		end
	end
end

-------------------------------------------------
-- PHANTOM WEAVER AI
-------------------------------------------------
function EnemyService:_updatePhantomWeaverAI(enemy: EnemyData, _dt: number, now: number)
	if not enemy.Alive then
		return
	end

	local body = enemy.Model and enemy.Model.PrimaryPart
	if not body then
		return
	end

	local cfg = (GameConfig.Enemies.Types :: any).PhantomWeaver
	local pos = body.Position

	-- Enrage
	if not _enraged and enemy.Health / enemy.MaxHealth <= cfg.EnrageThreshold then
		_enraged = true
		enemy.Speed *= 1.5
		local align = body:FindFirstChildOfClass("AlignPosition") :: AlignPosition?
		if align then
			align.MaxVelocity = enemy.Speed
		end
	end

	-- State machine
	if enemy.BossStateUntil and now < enemy.BossStateUntil then
		return
	end
	enemy.BossState = "CHASE"

	-- Teleport + spawn clones
	if now - (enemy.LastTeleportTime or 0) >= cfg.TeleportInterval then
		enemy.LastTeleportTime = now
		enemy.BossStateUntil = now + cfg.TeleportTelegraph + 0.3

		-- Telegraph then teleport
		task.delay(cfg.TeleportTelegraph, function()
			if not enemy.Alive then
				return
			end

			local target = self:_findClosestPlayer(pos)
			if target then
				local char = target.Character
				if char then
					local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
					if root then
						-- Teleport near target
						local offset = Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
						local newPos = root.Position + offset
						if body then
							local align = body:FindFirstChildOfClass("AlignPosition") :: AlignPosition?
							if align then
								align.Position = Vector3.new(newPos.X, body.Size.Y / 2, newPos.Z)
							end
							body.CFrame = CFrame.new(newPos.X, body.Size.Y / 2, newPos.Z)
						end

						-- Spawn shadow clones
						local cloneCount = math.min(cfg.CloneCount, GameService:GetMaxConcurrentEnemies() - #_enemies)
						for _ = 1, cloneCount do
							local cloneOffset = Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
							local clonePos = newPos + cloneOffset
							local clone = self:SpawnEnemy("Drone", clonePos)
							clone.Health = cfg.CloneHealth
							clone.MaxHealth = cfg.CloneHealth
							-- Auto-despawn clones after duration
							task.delay(cfg.CloneDuration, function()
								if clone.Alive then
									self:_killEnemy(clone, nil)
								end
							end)
						end
					end
				end
			end
		end)
		return
	end

	-- Shadow bolt
	if now - (enemy.LastShadowBolt or 0) >= cfg.ShadowBoltInterval then
		enemy.LastShadowBolt = now

		local target = self:_findClosestPlayer(pos)
		if target then
			local char = target.Character
			if char then
				local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					local dir = (root.Position - pos).Unit
					self.Client.ShadowBoltFired:FireAll(pos, dir)
					-- Reuse void bolt logic with shadow bolt config
					self:_fireBossProjectile(pos, dir, cfg.ShadowBoltSpeed, cfg.ShadowBoltDamage)
				end
			end
		end
	end
end

-------------------------------------------------
-- ABYSSAL SERPENT AI
-------------------------------------------------
function EnemyService:_updateAbyssalSerpentAI(enemy: EnemyData, _dt: number, now: number)
	if not enemy.Alive then
		return
	end

	local body = enemy.Model and enemy.Model.PrimaryPart
	if not body then
		return
	end

	local cfg = (GameConfig.Enemies.Types :: any).AbyssalSerpent
	local pos = body.Position

	-- Enrage
	if not _enraged and enemy.Health / enemy.MaxHealth <= cfg.EnrageThreshold then
		_enraged = true
		enemy.Damage = math.floor(enemy.Damage * 1.5)
		enemy.Speed *= 1.5
		local align = body:FindFirstChildOfClass("AlignPosition") :: AlignPosition?
		if align then
			align.MaxVelocity = enemy.Speed
		end
	end

	-- Handle active charge
	if enemy.ChargeState == "CHARGING" and enemy.ChargeUntil and now < enemy.ChargeUntil then
		if enemy.ChargeDirection and body then
			local align = body:FindFirstChildOfClass("AlignPosition") :: AlignPosition?
			if align then
				align.MaxVelocity = cfg.ChargeSpeed
				align.Position = pos + enemy.ChargeDirection * cfg.ChargeSpeed * _dt * 10
			end
			-- Damage players in path
			for _, player in Players:GetPlayers() do
				local stats = GameService:GetPlayerStats(player)
				if stats and stats.Health > 0 then
					local char = player.Character
					if char then
						local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
						if root and (root.Position - pos).Magnitude <= enemy.AttackRange then
							GameService:DamagePlayer(player, cfg.ChargeDamage)
						end
					end
				end
			end
		end
		return
	elseif enemy.ChargeState == "CHARGING" then
		-- Charge ended
		enemy.ChargeState = "IDLE"
		local align = body:FindFirstChildOfClass("AlignPosition") :: AlignPosition?
		if align then
			align.MaxVelocity = enemy.Speed
		end
	end

	-- State machine
	if enemy.BossStateUntil and now < enemy.BossStateUntil then
		return
	end
	enemy.BossState = "CHASE"

	-- Charge attack
	if now - (enemy.LastCharge or 0) >= cfg.ChargeInterval then
		enemy.LastCharge = now
		enemy.BossStateUntil = now + cfg.ChargeDuration

		local target = self:_findClosestPlayer(pos)
		if target then
			local char = target.Character
			if char then
				local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					local dir = (root.Position - pos)
					local flatDir = Vector3.new(dir.X, 0, dir.Z).Unit
					enemy.ChargeState = "CHARGING"
					enemy.ChargeDirection = flatDir
					enemy.ChargeUntil = now + cfg.ChargeDuration
					local endPos = pos + flatDir * cfg.ChargeSpeed * cfg.ChargeDuration
					self.Client.BossCharge:FireAll(pos, endPos)
				end
			end
		end
		return
	end

	-- Tail sweep
	if now - (enemy.LastTailSweep or 0) >= cfg.TailSweepInterval then
		enemy.LastTailSweep = now
		enemy.BossStateUntil = now + 0.5

		self.Client.TailSweep:FireAll(pos, cfg.TailSweepRadius)
		task.delay(0.3, function()
			if not enemy.Alive then
				return
			end
			for _, player in Players:GetPlayers() do
				local stats = GameService:GetPlayerStats(player)
				if stats and stats.Health > 0 then
					local char = player.Character
					if char then
						local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
						if root and (root.Position - pos).Magnitude <= cfg.TailSweepRadius then
							GameService:DamagePlayer(player, cfg.TailSweepDamage)
						end
					end
				end
			end
		end)
		return
	end

	-- Acid spit
	if now - (enemy.LastAcidSpit or 0) >= cfg.AcidSpitInterval then
		enemy.LastAcidSpit = now

		local target = self:_findClosestPlayer(pos)
		if target then
			local char = target.Character
			if char then
				local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					local dir = (root.Position - pos).Unit
					self:_fireBossProjectile(pos, dir, cfg.AcidSpitSpeed, cfg.AcidSpitDamage)
				end
			end
		end
	end
end

-------------------------------------------------
-- VOID ARCHITECT AI
-------------------------------------------------
function EnemyService:_updateVoidArchitectAI(enemy: EnemyData, _dt: number, now: number)
	if not enemy.Alive then
		return
	end

	local body = enemy.Model and enemy.Model.PrimaryPart
	if not body then
		return
	end

	local cfg = (GameConfig.Enemies.Types :: any).VoidArchitect
	local pos = body.Position

	-- Enrage
	if not _enraged and enemy.Health / enemy.MaxHealth <= cfg.EnrageThreshold then
		_enraged = true
		enemy.Damage = math.floor(enemy.Damage * 1.5)
	end

	-- Handle active laser
	if enemy.LaserState == "FIRING" and enemy.LaserUntil and now < enemy.LaserUntil then
		-- Damage players near laser line
		if enemy.LaserTarget then
			local laserDir = (enemy.LaserTarget - pos).Unit
			for _, player in Players:GetPlayers() do
				local stats = GameService:GetPlayerStats(player)
				if stats and stats.Health > 0 then
					local char = player.Character
					if char then
						local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
						if root then
							-- Simple proximity check to laser line
							local toPlayer = root.Position - pos
							local proj = toPlayer:Dot(laserDir)
							if proj > 0 and proj < cfg.LaserRange then
								local perpDist = (toPlayer - laserDir * proj).Magnitude
								if perpDist < 4 then
									GameService:DamagePlayer(player, cfg.LaserDamage)
								end
							end
						end
					end
				end
			end
		end
		return
	elseif enemy.LaserState == "FIRING" then
		enemy.LaserState = "IDLE"
	end

	-- State machine
	if enemy.BossStateUntil and now < enemy.BossStateUntil then
		return
	end
	enemy.BossState = "CHASE"

	-- Laser beam
	if now - (enemy.LastLaser or 0) >= cfg.LaserInterval then
		enemy.LastLaser = now
		enemy.BossStateUntil = now + cfg.LaserDuration

		local target = self:_findClosestPlayer(pos)
		if target then
			local char = target.Character
			if char then
				local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					enemy.LaserState = "FIRING"
					enemy.LaserTarget = root.Position
					enemy.LaserUntil = now + cfg.LaserDuration
					self.Client.BossLaser:FireAll(pos, root.Position, cfg.LaserDuration)
				end
			end
		end
		return
	end

	-- Place barriers
	if now - (enemy.LastBarrier or 0) >= cfg.BarrierInterval then
		enemy.LastBarrier = now
		enemy.BossStateUntil = now + 0.5

		for i = 1, cfg.BarrierCount do
			local angle = (i / cfg.BarrierCount) * math.pi * 2
			local barrierPos = pos + Vector3.new(math.cos(angle) * 12, 0, math.sin(angle) * 12)
			self.Client.BarrierPlaced:FireAll(barrierPos)

			-- Create barrier part
			task.spawn(function()
				local barrier = Instance.new("Part")
				barrier.Name = "VoidBarrier"
				barrier.Size = Vector3.new(6, 8, 2)
				barrier.Color = Color3.fromRGB(40, 20, 80)
				barrier.Material = Enum.Material.Neon
				barrier.Transparency = 0.3
				barrier.Anchored = true
				barrier.CanCollide = true
				barrier.CastShadow = false
				barrier.Position = Vector3.new(barrierPos.X, 4, barrierPos.Z)
				barrier.CFrame = CFrame.new(barrier.Position) * CFrame.Angles(0, angle, 0)
				barrier.Parent = _enemyFolder

				task.wait(cfg.BarrierDuration)
				if barrier.Parent then
					barrier:Destroy()
				end
			end)
		end
		return
	end

	-- Summon constructs
	if now - (enemy.LastSummon or 0) >= cfg.SummonInterval then
		enemy.LastSummon = now
		enemy.BossStateUntil = now + 1.0

		local spawnCount = math.min(cfg.SummonCount, GameService:GetMaxConcurrentEnemies() - #_enemies)
		for i = 1, spawnCount do
			local angle = (i / spawnCount) * math.pi * 2
			local spawnPos = pos + Vector3.new(math.cos(angle) * 8, 0, math.sin(angle) * 8)
			self:SpawnEnemy("Drone", spawnPos)
		end
	end
end

-------------------------------------------------
-- GENERIC BOSS PROJECTILE (reusable)
-------------------------------------------------
function EnemyService:_fireBossProjectile(startPos: Vector3, direction: Vector3, speed: number, damage: number)
	local bolt = Instance.new("Part")
	bolt.Name = "BossProjectile"
	bolt.Shape = Enum.PartType.Ball
	bolt.Size = Vector3.one * 1.5
	bolt.Color = Color3.fromRGB(80, 30, 120)
	bolt.Material = Enum.Material.Neon
	bolt.Anchored = true
	bolt.CanCollide = false
	bolt.CastShadow = false
	bolt.Position = startPos
	bolt.Parent = _enemyFolder

	task.spawn(function()
		local pos = startPos
		local maxDist = 60
		local traveled = 0

		while traveled < maxDist do
			local dt = task.wait()
			pos += direction * speed * dt
			bolt.Position = pos
			traveled += speed * dt

			-- Hit detection
			for _, player in Players:GetPlayers() do
				local stats = GameService:GetPlayerStats(player)
				if stats and stats.Health > 0 then
					local char = player.Character
					if char then
						local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
						if root and (root.Position - pos).Magnitude < 4 then
							GameService:DamagePlayer(player, damage)
							bolt:Destroy()
							return
						end
					end
				end
			end
		end

		bolt:Destroy()
	end)
end

function EnemyService:_fireVoidBolt(startPos: Vector3, direction: Vector3, cfg: any)
	-- Create a dark projectile
	local bolt = Instance.new("Part")
	bolt.Name = "VoidBolt"
	bolt.Shape = Enum.PartType.Ball
	bolt.Size = Vector3.one * 2
	bolt.Color = Color3.fromRGB(60, 20, 100)
	bolt.Material = Enum.Material.Neon
	bolt.Anchored = true
	bolt.CanCollide = false
	bolt.CastShadow = false
	bolt.Position = startPos
	bolt.Parent = _enemyFolder

	self.Client.VoidBoltFired:FireAll(startPos, direction)

	task.spawn(function()
		local pos = startPos
		local speed = cfg.VoidBoltSpeed or 40
		local damage = cfg.VoidBoltDamage or 25
		local maxDist = 80
		local traveled = 0

		while traveled < maxDist do
			local dt = task.wait()
			pos += direction * speed * dt
			bolt.Position = pos
			traveled += speed * dt

			-- Check player hits
			for _, player in Players:GetPlayers() do
				local stats = GameService:GetPlayerStats(player)
				if stats and stats.Health > 0 then
					local char = player.Character
					if char then
						local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
						if root and (root.Position - pos).Magnitude < 4 then
							GameService:DamagePlayer(player, damage)
							bolt:Destroy()
							return
						end
					end
				end
			end
		end

		bolt:Destroy()
	end)
end

-------------------------------------------------
-- WORM SYSTEM
-------------------------------------------------

function EnemyService:SpawnWorm(position: Vector3)
	local cfg = (GameConfig.Enemies.Types :: any).Worm
	local wave = GameService:GetCurrentWave()
	local waveCfg = GameConfig.Waves

	local healthMult = 1 + (wave - 1) * waveCfg.HealthScaling
	local damageMult = 1 + (wave - 1) * waveCfg.DamageScaling
	local speedMult = 1 + (wave - 1) * waveCfg.SpeedScaling

	local playerCount = GameService:GetPlayerCount()
	healthMult *= 1.0 + GameConfig.Scaling.EnemyHealthPerPlayer * (playerCount - 1)

	local segCount = cfg.SegmentCount or 6
	local spacing = cfg.SegmentSpacing or 3.5
	local wormId = _nextWormId
	_nextWormId += 1

	local wormData: WormData = {
		Id = wormId,
		Segments = {},
		Alive = true,
	}

	for i = 1, segCount do
		local isHead = (i == 1)
		local segPos = position + Vector3.new(0, 0, (i - 1) * spacing)
		local segModel = buildWormSegmentModel(cfg, segPos, i, isHead)

		local segHealth = math.floor(cfg.Health * healthMult)
		local xpVal = cfg.XPValue
		if isHead then
			xpVal += cfg.HeadXPBonus or 15
		end

		local enemyData: EnemyData = {
			Model = segModel,
			Type = "Worm",
			Health = segHealth,
			MaxHealth = segHealth,
			Speed = cfg.Speed * speedMult,
			Damage = math.floor(cfg.Damage * damageMult),
			AttackRange = cfg.AttackRange,
			AttackCooldown = cfg.AttackCooldown,
			XPValue = xpVal,
			LastAttackTime = 0,
			Target = nil,
			Alive = true,
			WormId = wormId,
			IsWormHead = isHead,
			SegmentIndex = i,
		}

		table.insert(_enemies, enemyData)
		table.insert(wormData.Segments, enemyData)
	end

	table.insert(_worms, wormData)
end

function EnemyService:_getWormData(wormId: number): WormData?
	for _, worm in _worms do
		if worm.Id == wormId then
			return worm
		end
	end
	return nil
end

function EnemyService:_updateWorms(dt: number)
	local cfg = (GameConfig.Enemies.Types :: any).Worm
	local spacing = cfg.SegmentSpacing or 3.5

	for _, worm in _worms do
		if not worm.Alive then
			continue
		end

		-- Remove dead segments
		local liveSegments: { EnemyData } = {}
		for _, seg in worm.Segments do
			if seg.Alive then
				table.insert(liveSegments, seg)
			end
		end
		worm.Segments = liveSegments

		if #liveSegments == 0 then
			worm.Alive = false
			continue
		end

		-- Head: chase closest player
		local head = liveSegments[1]
		if not head.IsWormHead then
			-- Promote to head (add eyes)
			head.IsWormHead = true
			head.XPValue += cfg.HeadXPBonus or 15
		end

		if head.Model and head.Model.PrimaryPart then
			local body = head.Model.PrimaryPart
			local pos = body.Position

			-- 1-segment worm = fast charging fragment
			local speed = head.Speed
			if #liveSegments == 1 then
				speed *= cfg.FragmentSpeedMult or 1.8
			end

			local target, dist = self:_findClosestPlayer(pos)
			head.Target = target

			if target then
				local char = target.Character
				if char then
					local targetRoot = char:FindFirstChild("HumanoidRootPart") :: BasePart?
					if targetRoot then
						local targetPos = targetRoot.Position
						local direction = Vector3.new(targetPos.X - pos.X, 0, targetPos.Z - pos.Z)

						local align = body:FindFirstChildOfClass("AlignPosition") :: AlignPosition?
						if align then
							align.MaxVelocity = speed
							if dist > head.AttackRange then
								local moveTarget = pos + direction.Unit * math.min(dist, speed * dt * 10)
								align.Position =
									Vector3.new(moveTarget.X, head.Model.PrimaryPart.Size.Y / 2, moveTarget.Z)
							else
								align.Position = Vector3.new(pos.X, head.Model.PrimaryPart.Size.Y / 2, pos.Z)
							end
						end

						local alignOrient = body:FindFirstChildOfClass("AlignOrientation") :: AlignOrientation?
						if alignOrient and direction.Magnitude > 0.1 then
							alignOrient.CFrame = CFrame.lookAt(Vector3.zero, direction.Unit)
						end

						-- Attack
						local now = tick()
						if dist <= head.AttackRange and (now - head.LastAttackTime) >= head.AttackCooldown then
							head.LastAttackTime = now
							GameService:DamagePlayer(target, head.Damage)
						end
					end
				end
			end
		end

		-- Tail segments: follow predecessor
		for i = 2, #liveSegments do
			local seg = liveSegments[i]
			local predecessor = liveSegments[i - 1]

			if not seg.Model or not seg.Model.PrimaryPart then
				continue
			end
			if not predecessor.Model or not predecessor.Model.PrimaryPart then
				continue
			end

			local segBody = seg.Model.PrimaryPart
			local predPos = predecessor.Model.PrimaryPart.Position
			local segPos = segBody.Position
			local towardPred = predPos - segPos
			local flatDir = Vector3.new(towardPred.X, 0, towardPred.Z)
			local currentDist = flatDir.Magnitude

			local align = segBody:FindFirstChildOfClass("AlignPosition") :: AlignPosition?
			if align then
				align.MaxVelocity = seg.Speed
				if currentDist > spacing then
					local moveTarget = segPos + flatDir.Unit * (currentDist - spacing)
					align.Position = Vector3.new(moveTarget.X, seg.Model.PrimaryPart.Size.Y / 2, moveTarget.Z)
				else
					align.Position = Vector3.new(segPos.X, seg.Model.PrimaryPart.Size.Y / 2, segPos.Z)
				end
			end

			-- Face toward predecessor
			local alignOrient = segBody:FindFirstChildOfClass("AlignOrientation") :: AlignOrientation?
			if alignOrient and flatDir.Magnitude > 0.1 then
				alignOrient.CFrame = CFrame.lookAt(Vector3.zero, flatDir.Unit)
			end
		end
	end
end

function EnemyService:_splitWorm(worm: WormData, deadSegmentIndex: number)
	-- When a middle segment dies, split worm into two independent worms
	-- deadSegmentIndex is the index within worm.Segments before removal

	local frontSegments: { EnemyData } = {}
	local backSegments: { EnemyData } = {}

	for i, seg in worm.Segments do
		if i < deadSegmentIndex then
			table.insert(frontSegments, seg)
		elseif i > deadSegmentIndex then
			table.insert(backSegments, seg)
		end
	end

	-- The original worm keeps the front portion
	worm.Segments = frontSegments
	if #frontSegments == 0 then
		worm.Alive = false
	end

	-- Create a new worm for the back portion
	if #backSegments > 0 then
		local newWormId = _nextWormId
		_nextWormId += 1

		local newWorm: WormData = {
			Id = newWormId,
			Segments = backSegments,
			Alive = true,
		}

		-- Update worm IDs on back segments
		for _, seg in backSegments do
			seg.WormId = newWormId
		end

		-- Promote first back segment to head
		backSegments[1].IsWormHead = true
		local cfg = (GameConfig.Enemies.Types :: any).Worm
		backSegments[1].XPValue += cfg.HeadXPBonus or 15

		table.insert(_worms, newWorm)
	end
end

-------------------------------------------------
-- NEW ENEMY AI
-------------------------------------------------

function EnemyService:_fireSpitterProjectile(startPos: Vector3, targetPos: Vector3, cfg: any)
	local dir = (targetPos - startPos).Unit
	local bolt = Instance.new("Part")
	bolt.Name = "SpitterGlob"
	bolt.Shape = Enum.PartType.Ball
	bolt.Size = Vector3.one * 1.5
	bolt.Color = Color3.fromRGB(80, 200, 40)
	bolt.Material = Enum.Material.Neon
	bolt.Anchored = true
	bolt.CanCollide = false
	bolt.CastShadow = false
	bolt.Position = startPos + Vector3.new(0, 2, 0)
	bolt.Parent = _enemyFolder

	task.spawn(function()
		local pos = startPos + Vector3.new(0, 2, 0)
		local speed = cfg.ProjectileSpeed
		local damage = cfg.ProjectileDamage
		local maxDist = 60
		local traveled = 0

		while traveled < maxDist and bolt.Parent do
			local dt2 = game:GetService("RunService").Heartbeat:Wait()
			pos += dir * speed * dt2
			bolt.Position = pos
			traveled += speed * dt2

			-- Check player hits
			for player, stats in pairs(GameService:GetAllPlayerStats()) do
				if stats.Health <= 0 then
					continue
				end
				local char = player.Character
				if not char then
					continue
				end
				local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and (root.Position - pos).Magnitude < 3 then
					GameService:DamagePlayer(player, damage)
					bolt:Destroy()
					return
				end
			end
		end
		if bolt.Parent then
			bolt:Destroy()
		end
	end)
end

function EnemyService:_updateLurker(enemy: EnemyData, _dt: number, now: number)
	if not enemy.Model or not enemy.Model.PrimaryPart then
		return
	end
	local cfg = (GameConfig.Enemies.Types :: any).Lurker
	local body = enemy.Model.PrimaryPart
	local pos = body.Position

	local phase = enemy.TeleportPhase or "VISIBLE"

	if phase == "VISIBLE" then
		-- Normal chase until teleport interval
		if (now - (enemy.LastTeleportTime or 0)) >= cfg.TeleportInterval then
			enemy.TeleportPhase = "TELEGRAPH"
			enemy.TeleportPhaseUntil = now + cfg.TeleportTelegraph
			-- Visual telegraph: make semi-transparent
			body.Transparency = 0.7
		else
			-- Chase closest player
			local target, dist = self:_findClosestPlayer(pos)
			if target and target.Character then
				local targetRoot = target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if targetRoot then
					local dir = (targetRoot.Position - pos)
					local flat = Vector3.new(dir.X, 0, dir.Z)
					local align = body:FindFirstChildOfClass("AlignPosition") :: AlignPosition?
					if align and dist > enemy.AttackRange then
						align.Position = pos + flat.Unit * enemy.Speed * 0.5
					end
					if dist <= enemy.AttackRange and (now - enemy.LastAttackTime) >= enemy.AttackCooldown then
						enemy.LastAttackTime = now
						GameService:DamagePlayer(target, enemy.Damage)
					end
				end
			end
		end
	elseif phase == "TELEGRAPH" then
		if now >= (enemy.TeleportPhaseUntil or 0) then
			-- Teleport near closest player
			local target = self:_findClosestPlayer(pos)
			if target and target.Character then
				local targetRoot = target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if targetRoot then
					local angle = math.random() * math.pi * 2
					local dist2 = math.random() * cfg.TeleportRange
					local newPos = targetRoot.Position
						+ Vector3.new(math.cos(angle) * dist2, 0, math.sin(angle) * dist2)
					local align = body:FindFirstChildOfClass("AlignPosition") :: AlignPosition?
					if align then
						align.Position = Vector3.new(newPos.X, body.Size.Y / 2, newPos.Z)
					end
					body.CFrame = CFrame.new(newPos.X, body.Size.Y / 2, newPos.Z)
				end
			end
			enemy.TeleportPhase = "VISIBLE"
			enemy.LastTeleportTime = now
			body.Transparency = 0
		end
	end
end

function EnemyService:_updateBurrower(enemy: EnemyData, _dt: number, now: number)
	if not enemy.Model or not enemy.Model.PrimaryPart then
		return
	end
	local cfg = (GameConfig.Enemies.Types :: any).Burrower
	local body = enemy.Model.PrimaryPart
	local pos = body.Position

	local state = enemy.BurrowState or "SURFACED"

	if state == "SURFACED" then
		if now >= (enemy.BurrowStateUntil or 0) then
			-- Burrow underground
			enemy.BurrowState = "BURROWED"
			enemy.BurrowStateUntil = now + cfg.BurrowDuration
			body.Transparency = 0.9
			-- Move underground visually
			local align = body:FindFirstChildOfClass("AlignPosition") :: AlignPosition?
			if align then
				align.Position = Vector3.new(pos.X, -1, pos.Z)
			end
		else
			-- Normal chase + attack while surfaced
			local target, dist = self:_findClosestPlayer(pos)
			if target and target.Character then
				local targetRoot = target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if targetRoot then
					local dir = (targetRoot.Position - pos)
					local flat = Vector3.new(dir.X, 0, dir.Z)
					local align = body:FindFirstChildOfClass("AlignPosition") :: AlignPosition?
					if align and dist > enemy.AttackRange then
						align.Position = pos + flat.Unit * enemy.Speed * 0.5
					end
					if dist <= enemy.AttackRange and (now - enemy.LastAttackTime) >= enemy.AttackCooldown then
						enemy.LastAttackTime = now
						GameService:DamagePlayer(target, enemy.Damage)
					end
				end
			end
		end
	elseif state == "BURROWED" then
		-- Move toward player underground (fast)
		local target = self:_findClosestPlayer(pos)
		if target and target.Character then
			local targetRoot = target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if targetRoot then
				local dir = (targetRoot.Position - pos)
				local flat = Vector3.new(dir.X, 0, dir.Z)
				local align = body:FindFirstChildOfClass("AlignPosition") :: AlignPosition?
				if align then
					align.Position = pos + flat.Unit * enemy.Speed * 1.5 * 0.5
					align.Position = Vector3.new(align.Position.X, -1, align.Position.Z)
				end
			end
		end

		if now >= (enemy.BurrowStateUntil or 0) then
			-- Surface near player
			enemy.BurrowState = "SURFACED"
			enemy.BurrowStateUntil = now + cfg.SurfaceDuration
			body.Transparency = 0
			local align = body:FindFirstChildOfClass("AlignPosition") :: AlignPosition?
			if align then
				align.Position = Vector3.new(pos.X, body.Size.Y / 2, pos.Z)
			end
			-- Damage nearby players on surface
			local target2 = self:_findClosestPlayer(pos)
			if target2 then
				local char = target2.Character
				if char then
					local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
					if root and (root.Position - pos).Magnitude < 8 then
						GameService:DamagePlayer(target2, enemy.Damage)
					end
				end
			end
		end
	end
end

function EnemyService:_updateVoidWraith(enemy: EnemyData, _dt: number, now: number)
	if not enemy.Model or not enemy.Model.PrimaryPart then
		return
	end
	local cfg = (GameConfig.Enemies.Types :: any).VoidWraith
	local body = enemy.Model.PrimaryPart
	local pos = body.Position

	local phase = enemy.PhaseState or "SOLID"

	-- Toggle phase
	if now >= (enemy.PhaseStateUntil or 0) then
		if phase == "SOLID" then
			enemy.PhaseState = "PHASED"
			enemy.PhaseStateUntil = now + cfg.PhaseDuration
			body.Transparency = 0.8
		else
			enemy.PhaseState = "SOLID"
			enemy.PhaseStateUntil = now + cfg.PhaseInterval
			body.Transparency = 0.2
		end
	end

	-- Chase and attack (only when solid)
	local target, dist = self:_findClosestPlayer(pos)
	if target and target.Character then
		local targetRoot = target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if targetRoot then
			local dir = (targetRoot.Position - pos)
			local flat = Vector3.new(dir.X, 0, dir.Z)
			local align = body:FindFirstChildOfClass("AlignPosition") :: AlignPosition?
			if align and dist > enemy.AttackRange then
				align.Position = pos + flat.Unit * enemy.Speed * 0.5
			end
			if
				enemy.PhaseState == "SOLID"
				and dist <= enemy.AttackRange
				and (now - enemy.LastAttackTime) >= enemy.AttackCooldown
			then
				enemy.LastAttackTime = now
				GameService:DamagePlayer(target, enemy.Damage)
			end
		end
	end
end

-------------------------------------------------
-- ENEMY UPDATE LOOP
-------------------------------------------------

function EnemyService:_updateEnemies(dt: number)
	local now = tick()

	for _, enemy in _enemies do
		if not enemy.Alive then
			continue
		end
		if not enemy.Model or not enemy.Model.Parent or not enemy.Model.PrimaryPart then
			continue
		end

		-- Custom AI for specific enemy types
		if enemy.Type == "Shade" then
			self:_updateShade(enemy, dt, now)
			continue
		end
		if enemy.Type == "Worm" then
			continue
		end
		if enemy.Type == "Lurker" then
			self:_updateLurker(enemy, dt, now)
			continue
		end
		if enemy.Type == "Burrower" then
			self:_updateBurrower(enemy, dt, now)
			continue
		end
		if enemy.Type == "VoidWraith" then
			self:_updateVoidWraith(enemy, dt, now)
			continue
		end

		-- Boss has attack AI layered on top of chase
		if enemy.Type == "MegaBoss" then
			self:_updateBossAI(enemy, dt, now)
		elseif enemy.Type == "BroodQueen" then
			self:_updateBroodQueenAI(enemy, dt, now)
		elseif enemy.Type == "PhantomWeaver" then
			self:_updatePhantomWeaverAI(enemy, dt, now)
		elseif enemy.Type == "AbyssalSerpent" then
			self:_updateAbyssalSerpentAI(enemy, dt, now)
		elseif enemy.Type == "VoidArchitect" then
			self:_updateVoidArchitectAI(enemy, dt, now)
		end

		local body = enemy.Model.PrimaryPart
		local pos = body.Position

		-- Kill enemies that fall off the map
		if pos.Y < -50 then
			self:_killEnemy(enemy, nil)
			continue
		end

		-- Find target
		local target, dist = self:_findClosestPlayer(pos)
		enemy.Target = target

		if not target then
			continue
		end

		local char = target.Character
		if not char then
			continue
		end
		local targetRoot = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not targetRoot then
			continue
		end

		local targetPos = targetRoot.Position
		local direction = (targetPos - pos)
		local flatDirection = Vector3.new(direction.X, 0, direction.Z)

		-- Move toward target
		local align = body:FindFirstChildOfClass("AlignPosition") :: AlignPosition?
		if align then
			if dist > enemy.AttackRange then
				local moveTarget = pos + flatDirection.Unit * math.min(dist, enemy.Speed * dt * 10)
				align.Position = Vector3.new(moveTarget.X, enemy.Model.PrimaryPart.Size.Y / 2, moveTarget.Z)
			else
				align.Position = Vector3.new(pos.X, enemy.Model.PrimaryPart.Size.Y / 2, pos.Z)
			end
		end

		-- Face target
		local alignOrient = body:FindFirstChildOfClass("AlignOrientation") :: AlignOrientation?
		if alignOrient and flatDirection.Magnitude > 0.1 then
			alignOrient.CFrame = CFrame.lookAt(Vector3.zero, flatDirection.Unit)
		end

		-- Spitter: ranged attack, retreats if player is close
		if enemy.Type == "Spitter" then
			local spitterCfg = (GameConfig.Enemies.Types :: any).Spitter
			if dist < spitterCfg.RetreatRange and align then
				-- Retreat away from player
				local retreatDir = -flatDirection.Unit
				local retreatPos = pos + retreatDir * enemy.Speed * dt * 10
				align.Position = Vector3.new(retreatPos.X, body.Size.Y / 2, retreatPos.Z)
			end
			if (now - enemy.LastAttackTime) >= enemy.AttackCooldown and dist <= enemy.AttackRange then
				enemy.LastAttackTime = now
				self:_fireSpitterProjectile(pos, targetPos, spitterCfg)
			end
			continue
		end

		-- Broodmother: spawns swarmlings periodically
		if enemy.Type == "Broodmother" then
			local bmCfg = (GameConfig.Enemies.Types :: any).Broodmother
			if (now - (enemy.LastSpawnTime or 0)) >= bmCfg.SpawnInterval then
				enemy.LastSpawnTime = now
				local maxConcurrent = GameService:GetMaxConcurrentEnemies()
				local spawnCount = math.min(bmCfg.SpawnCount, maxConcurrent - #_enemies)
				for s = 1, spawnCount do
					local angle = (s / spawnCount) * math.pi * 2
					local spawnPos = pos + Vector3.new(math.cos(angle) * 4, 0, math.sin(angle) * 4)
					self:SpawnEnemy("Swarmling", spawnPos)
				end
			end
		end

		-- Leech: attaches to player on contact
		if enemy.Type == "Leech" and enemy.AttachedTo then
			-- Already attached — drain HP
			local attachedChar = enemy.AttachedTo.Character
			if not attachedChar or enemy.AttachedTo.Parent ~= Players then
				enemy.AttachedTo = nil
			else
				local leechCfg = (GameConfig.Enemies.Types :: any).Leech
				if (now - enemy.LastAttackTime) >= 1.0 then
					enemy.LastAttackTime = now
					GameService:DamagePlayer(enemy.AttachedTo, leechCfg.DrainDPS)
				end
				-- Follow attached player
				local attachRoot = attachedChar:FindFirstChild("HumanoidRootPart") :: BasePart?
				if attachRoot and align then
					align.Position = attachRoot.Position + Vector3.new(0, 2, 0)
				end
			end
			continue
		end

		-- Hivemind: buffs nearby enemies
		if enemy.Type == "Hivemind" then
			local hmCfg = (GameConfig.Enemies.Types :: any).Hivemind
			for _, other in _enemies do
				if other == enemy or not other.Alive or not other.Model or not other.Model.PrimaryPart then
					continue
				end
				local otherDist = (other.Model.PrimaryPart.Position - pos).Magnitude
				if otherDist <= hmCfg.BuffRadius then
					local otherAlign = other.Model.PrimaryPart:FindFirstChildOfClass("AlignPosition") :: AlignPosition?
					if otherAlign then
						otherAlign.MaxVelocity = other.Speed * (1 + hmCfg.SpeedBuff)
					end
				end
			end
		end

		-- Attack (melee)
		if dist <= enemy.AttackRange and (now - enemy.LastAttackTime) >= enemy.AttackCooldown then
			enemy.LastAttackTime = now

			-- Leech: try to attach instead of normal damage
			if enemy.Type == "Leech" and not enemy.AttachedTo then
				local leechCfg = (GameConfig.Enemies.Types :: any).Leech
				-- Count existing leeches on this player
				local attachedCount = 0
				for _, e in _enemies do
					if e.Type == "Leech" and e.AttachedTo == target then
						attachedCount += 1
					end
				end
				if attachedCount < leechCfg.MaxAttached then
					enemy.AttachedTo = target
				end
				continue
			end

			GameService:DamagePlayer(target, enemy.Damage)
		end
	end
end

function EnemyService:_getAvailableTypes(wave: number, gameElapsed: number): { string }
	local waveCfg = GameConfig.Waves
	local enemyCfg = GameConfig.Enemies

	local types = { "Drone" }
	if wave >= waveCfg.BruteIntroWave then
		table.insert(types, "Brute")
	end
	if wave >= waveCfg.DasherIntroWave then
		table.insert(types, "Dasher")
	end

	-- Time-based introductions
	for typeName, introTime in enemyCfg.IntroTimes do
		if typeName ~= "Worm" and gameElapsed >= introTime and not table.find(types, typeName) then
			table.insert(types, typeName)
		end
	end

	return types
end

function EnemyService:_spawnWaveEnemies(wave: number, totalEnemies: number)
	_spawning = true
	local waveCfg = GameConfig.Waves
	local maxConcurrent = GameService:GetMaxConcurrentEnemies()

	-- Calculate spawn interval with acceleration
	local spawnInterval =
		math.max(waveCfg.MinSpawnInterval, waveCfg.SpawnInterval - (wave - 1) * waveCfg.SpawnIntervalDecayPerWave)

	local gameElapsed = GameService:GetGameElapsed()
	local types = self:_getAvailableTypes(wave, gameElapsed)

	local rng = Random.new()
	local spawned = 0

	while spawned < totalEnemies and _spawning do
		-- Don't exceed concurrent limit
		if #_enemies >= maxConcurrent then
			task.wait(0.5)
			continue
		end

		local enemyType = types[rng:NextInteger(1, #types)]

		-- Shade spawns in flocks
		if enemyType == "Shade" then
			local shadeCfg = (GameConfig.Enemies.Types :: any).Shade
			local flockSize = shadeCfg.FlockSize or 3
			local positions = ArenaService:GetSpawnPositions(flockSize)
			for f = 1, math.min(flockSize, totalEnemies - spawned) do
				if #_enemies < maxConcurrent then
					self:SpawnEnemy("Shade", positions[f] or positions[1])
					spawned += 1
				end
			end
		elseif enemyType == "Swarmling" then
			-- Swarmlings spawn in large flocks
			local swarmCfg = (GameConfig.Enemies.Types :: any).Swarmling
			local flockSize = swarmCfg.FlockSize or 10
			local positions = ArenaService:GetSpawnPositions(flockSize)
			for f = 1, math.min(flockSize, totalEnemies - spawned) do
				if #_enemies < maxConcurrent then
					self:SpawnEnemy("Swarmling", positions[f] or positions[1])
					spawned += 1
				end
			end
		else
			local positions = ArenaService:GetSpawnPositions(1)
			self:SpawnEnemy(enemyType, positions[1])
			spawned += 1
		end

		if spawned < totalEnemies then
			task.wait(spawnInterval)
		end
	end

	-- Spawn worms if unlocked
	local wormCfg = (GameConfig.Enemies.Types :: any).Worm
	local wormElapsed = GameService:GetGameElapsed()
	if wave >= (waveCfg.WormIntroWave or 8) and wormElapsed >= (wormCfg.IntroTime or 180) then
		local wormCount = math.min(wormCfg.MaxPerWave or 2, maxConcurrent - #_enemies)
		for _ = 1, wormCount do
			if #_enemies < maxConcurrent then
				local positions = ArenaService:GetSpawnPositions(1)
				self:SpawnWorm(positions[1])
			end
		end
	end

	_spawning = false
end

function EnemyService:_checkBossSpawn()
	-- Only spawn bosses during active waves
	if GameService:GetState() ~= "Wave" then
		return
	end

	local enemyCfg = GameConfig.Enemies
	local gameElapsed = GameService:GetGameElapsed()

	if gameElapsed < enemyCfg.BossStartTime then
		return
	end

	if #_enemies >= GameService:GetMaxConcurrentEnemies() then
		return
	end

	local timeSinceLastBoss = gameElapsed - _lastBossSpawnTime
	local shouldSpawn = false
	if _lastBossSpawnTime == 0 then
		shouldSpawn = gameElapsed >= enemyCfg.BossStartTime
	else
		shouldSpawn = timeSinceLastBoss >= enemyCfg.BossInterval
	end

	if shouldSpawn then
		_lastBossSpawnTime = gameElapsed
		_bossSpawnCount += 1

		-- Rotate through boss types
		local rotation = GameConfig.Enemies.BossRotation
		local bossType = rotation[(((_bossSpawnCount - 1) % #rotation) + 1)]

		local positions = ArenaService:GetSpawnPositions(1)
		self:SpawnEnemy(bossType, positions[1])
		-- Add boss to wave enemy count so it doesn't end the wave early
		local remaining = GameService:GetEnemiesRemaining()
		GameService:SetEnemiesRemaining(remaining + 1)
		-- Notify clients for VFX
		CombatService.Client.BossSpawned:FireAll()
	end
end

function EnemyService:_clearAllEnemies()
	_spawning = false
	for _, enemy in _enemies do
		if enemy.Model and enemy.Model.Parent then
			enemy.Model:Destroy()
		end
	end
	table.clear(_enemies)
	table.clear(_worms)
end

function EnemyService:GetEnemyFromModel(model: Model): EnemyData?
	for _, enemy in _enemies do
		if enemy.Model == model then
			return enemy
		end
	end
	return nil
end

function EnemyService:GetEnemiesInRadius(position: Vector3, radius: number): { EnemyData }
	local result: { EnemyData } = {}
	for _, enemy in _enemies do
		if enemy.Alive and enemy.Model and enemy.Model.PrimaryPart then
			local dist = (enemy.Model.PrimaryPart.Position - position).Magnitude
			if dist <= radius then
				table.insert(result, enemy)
			end
		end
	end
	return result
end

function EnemyService:KnitInit()
	_enemyFolder = Instance.new("Folder")
	_enemyFolder.Name = "Enemies"
	_enemyFolder.Parent = workspace
end

function EnemyService:KnitStart()
	GameService = Knit.GetService("GameService")
	ArenaService = Knit.GetService("ArenaService")
	CombatService = Knit.GetService("CombatService")
	StatsService = Knit.GetService("StatsService")

	-- Listen for wave starts
	GameService.WaveStarted:Connect(function(wave: number, enemyCount: number)
		task.spawn(function()
			self:_spawnWaveEnemies(wave, enemyCount)
		end)
	end)

	-- Clear enemies on game over / victory / lobby
	GameService.GameStateChanged:Connect(function(state: string)
		if state == "GameOver" or state == "Victory" or state == "WaitingForPlayers" or state == "Lobby" then
			self:_clearAllEnemies()
			_lastBossSpawnTime = 0
			_bossSpawnCount = 0
			_megaBossEnemy = nil
			_enraged = false
		elseif state == "MegaBoss" then
			-- Spawn the mega-boss
			task.spawn(function()
				local positions = ArenaService:GetSpawnPositions(1)
				local megaBoss = self:SpawnEnemy("MegaBoss", positions[1])
				_megaBossEnemy = megaBoss
				-- Notify clients
				CombatService.Client.BossSpawned:FireAll()
			end)
		elseif state == "Enrage" and not _enraged then
			-- Enrage is now handled inside _updateBossAI based on HP threshold
			-- but keep this as a fallback for the game timer enrage
			_enraged = true
			if _megaBossEnemy and _megaBossEnemy.Alive then
				_megaBossEnemy.Damage = math.floor(_megaBossEnemy.Damage * 2)
				_megaBossEnemy.Speed *= 1.5
				if _megaBossEnemy.Model and _megaBossEnemy.Model.PrimaryPart then
					local align =
						_megaBossEnemy.Model.PrimaryPart:FindFirstChildOfClass("AlignPosition") :: AlignPosition?
					if align then
						align.MaxVelocity = _megaBossEnemy.Speed
					end
				end
			end
		end
	end)

	-- AI update loop + boss spawn check
	game:GetService("RunService").Heartbeat:Connect(function(dt: number)
		self:_updateEnemies(dt)
		self:_updateWorms(dt)
		self:_checkBossSpawn()
	end)
end

return EnemyService
