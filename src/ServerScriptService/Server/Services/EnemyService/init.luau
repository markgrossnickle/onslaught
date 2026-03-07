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
	},

	EnemyKilled = Signal.new(), -- (enemyData, killerPlayer)
})

local _enemies: { EnemyData } = {}
local _worms: { WormData } = {}
local _nextWormId: number = 1
local _enemyFolder: Folder = nil :: any
local _spawning: boolean = false
local _lastBossSpawnTime: number = 0
local _megaBossEnemy: EnemyData? = nil
local _enraged: boolean = false

local GameService: any
local ArenaService: any
local CombatService: any

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
	elseif enemyType == "MegaBoss" or enemyType == "Boss" then
		body = buildBossModel(cfg, position, model, enemyType == "MegaBoss")
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
	if enemyType == "Boss" or enemyType == "MegaBoss" then
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

	-- MegaBoss: init attack timers
	if enemyType == "MegaBoss" then
		local now = tick()
		enemyData.BossState = "CHASE"
		enemyData.LastVoidBolt = now
		enemyData.LastSlam = now
		enemyData.LastSpawnMinions = now
		enemyData.LastVoidPull = now
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
	if enemy.Type == "MegaBoss" then
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

	-- Check if mega-boss was killed
	if enemy.Type == "MegaBoss" then
		_megaBossEnemy = nil
		GameService:MegaBossKilled()
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

		-- Shade has custom AI
		if enemy.Type == "Shade" then
			self:_updateShade(enemy, dt, now)
			continue
		end

		-- Worm segments are handled by _updateWorms
		if enemy.Type == "Worm" then
			continue
		end

		-- Boss has attack AI layered on top of chase
		if enemy.Type == "MegaBoss" then
			self:_updateBossAI(enemy, dt, now)
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

		-- Attack (melee)
		if dist <= enemy.AttackRange and (now - enemy.LastAttackTime) >= enemy.AttackCooldown then
			enemy.LastAttackTime = now
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
		local positions = ArenaService:GetSpawnPositions(1)
		self:SpawnEnemy("Boss", positions[1])
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
