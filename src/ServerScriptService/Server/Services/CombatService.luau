--!strict
--[=[
	Auto-attack weapon system (Vampire Survivors style).
	Weapons fire automatically — player only controls movement.
	12 base weapons + 6 evolutions.
]=]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local CombatService = Knit.CreateService({
	Name = "CombatService",
	Client = {
		OrbiterSync = Knit.CreateSignal(),
		ProjectileFired = Knit.CreateSignal(),
		ProjectileImpact = Knit.CreateSignal(), -- (position: Vector3)
		LightningFired = Knit.CreateSignal(), -- (startPos, endPos, chainPositions)
		AuraSync = Knit.CreateSignal(), -- (playerPos, radius)
		BossSpawned = Knit.CreateSignal(), -- ()
		WhipSlash = Knit.CreateSignal(), -- (position, direction, arcAngle)
		DaggersFired = Knit.CreateSignal(), -- (position, directions)
		GravityWellPlaced = Knit.CreateSignal(), -- (position, radius, duration)
		ShockwaveBlast = Knit.CreateSignal(), -- (position, radius)
		ScytheFired = Knit.CreateSignal(), -- (position, direction)
		SoulDrainBeam = Knit.CreateSignal(), -- (startPos, endPos)
		MissilesFired = Knit.CreateSignal(), -- (positions, directions)
		EvolutionActivated = Knit.CreateSignal(), -- (evolutionId)
	},
})

local GameService: any
local EnemyService: any
local StatsService: any

-- Per-player weapon state
export type WeaponState = {
	-- Original weapons
	HasOrbiter: boolean,
	OrbiterCount: number,
	OrbiterDamage: number,
	OrbiterAngle: number,
	OrbiterHitTimers: { [Model]: number },

	HasProjectile: boolean,
	ProjectileDamage: number,
	ProjectileFireInterval: number,
	ProjectilePierce: number,
	LastProjectileTime: number,

	HasLightning: boolean,
	LightningDamage: number,
	LightningRange: number,
	LightningFireInterval: number,
	LightningChainCount: number,
	LightningChainRange: number,
	LastLightningTime: number,

	HasAura: boolean,
	AuraDamage: number,
	AuraRadius: number,
	AuraTickInterval: number,
	LastAuraTickTime: number,

	-- New weapons
	HasVoidWhip: boolean,
	VoidWhipDamage: number,
	VoidWhipRange: number,
	VoidWhipArc: number,
	VoidWhipInterval: number,
	LastVoidWhipTime: number,

	HasShadowDaggers: boolean,
	ShadowDaggerDamage: number,
	ShadowDaggerCount: number,
	ShadowDaggerInterval: number,
	LastShadowDaggerTime: number,

	HasGravityWell: boolean,
	GravityWellDamage: number,
	GravityWellRadius: number,
	GravityWellDuration: number,
	GravityWellInterval: number,
	LastGravityWellTime: number,

	HasPlagueCloud: boolean,
	PlagueDamage: number,
	PlagueRadius: number,
	PlagueTickInterval: number,
	PlagueSlow: number,
	LastPlagueTickTime: number,

	HasVoidMissiles: boolean,
	MissileDamage: number,
	MissileCount: number,
	MissileInterval: number,
	LastMissileTime: number,

	HasSpectralScythe: boolean,
	ScytheDamageOut: number,
	ScytheDamageReturn: number,
	ScytheRange: number,
	ScytheInterval: number,
	LastScytheTime: number,

	HasSoulDrain: boolean,
	SoulDrainDamage: number,
	SoulDrainRange: number,
	SoulDrainHeal: number,
	SoulDrainTickInterval: number,
	LastSoulDrainTick: number,

	HasShockwave: boolean,
	ShockwaveDamage: number,
	ShockwaveRadius: number,
	ShockwaveKnockback: number,
	ShockwaveInterval: number,
	LastShockwaveTime: number,

	-- Evolutions (replaces ingredient weapons)
	Evolutions: { [string]: boolean },

	-- Weapon levels (1 = acquired, max 8)
	WeaponLevels: { [string]: number },
}

local _weaponStates: { [Player]: WeaponState } = {}
local _orbiterParts: { [Player]: { BasePart } } = {}
local _auraParts: { [Player]: BasePart } = {}
local _projectileFolder: Folder = nil :: any

function CombatService:_initWeaponState(player: Player): WeaponState
	local cfg = GameConfig.Weapons.Orbiter
	local lightCfg = GameConfig.Weapons.Lightning
	local auraCfg = GameConfig.Weapons.Aura
	local whipCfg = GameConfig.Weapons.VoidWhip
	local daggerCfg = GameConfig.Weapons.ShadowDaggers
	local gravCfg = GameConfig.Weapons.GravityWell
	local plagueCfg = GameConfig.Weapons.PlagueCloud
	local missileCfg = GameConfig.Weapons.VoidMissiles
	local scytheCfg = GameConfig.Weapons.SpectralScythe
	local drainCfg = GameConfig.Weapons.SoulDrain
	local shockCfg = GameConfig.Weapons.Shockwave

	local state: WeaponState = {
		HasOrbiter = true,
		OrbiterCount = cfg.InitialCount,
		OrbiterDamage = cfg.Damage,
		OrbiterAngle = 0,
		OrbiterHitTimers = {},

		HasProjectile = false,
		ProjectileDamage = GameConfig.Weapons.Projectile.Damage,
		ProjectileFireInterval = GameConfig.Weapons.Projectile.FireInterval,
		ProjectilePierce = GameConfig.Weapons.Projectile.Pierce,
		LastProjectileTime = 0,

		HasLightning = false,
		LightningDamage = lightCfg.Damage,
		LightningRange = lightCfg.Range,
		LightningFireInterval = lightCfg.FireInterval,
		LightningChainCount = lightCfg.ChainCount,
		LightningChainRange = lightCfg.ChainRange,
		LastLightningTime = 0,

		HasAura = false,
		AuraDamage = auraCfg.Damage,
		AuraRadius = auraCfg.Radius,
		AuraTickInterval = auraCfg.TickInterval,
		LastAuraTickTime = 0,

		HasVoidWhip = false,
		VoidWhipDamage = whipCfg.Damage,
		VoidWhipRange = whipCfg.Range,
		VoidWhipArc = whipCfg.ArcAngle,
		VoidWhipInterval = whipCfg.FireInterval,
		LastVoidWhipTime = 0,

		HasShadowDaggers = false,
		ShadowDaggerDamage = daggerCfg.Damage,
		ShadowDaggerCount = daggerCfg.DaggerCount,
		ShadowDaggerInterval = daggerCfg.FireInterval,
		LastShadowDaggerTime = 0,

		HasGravityWell = false,
		GravityWellDamage = gravCfg.Damage,
		GravityWellRadius = gravCfg.Radius,
		GravityWellDuration = gravCfg.Duration,
		GravityWellInterval = gravCfg.FireInterval,
		LastGravityWellTime = 0,

		HasPlagueCloud = false,
		PlagueDamage = plagueCfg.Damage,
		PlagueRadius = plagueCfg.Radius,
		PlagueTickInterval = plagueCfg.TickInterval,
		PlagueSlow = plagueCfg.SlowPercent,
		LastPlagueTickTime = 0,

		HasVoidMissiles = false,
		MissileDamage = missileCfg.Damage,
		MissileCount = missileCfg.MissileCount,
		MissileInterval = missileCfg.FireInterval,
		LastMissileTime = 0,

		HasSpectralScythe = false,
		ScytheDamageOut = scytheCfg.DamageOut,
		ScytheDamageReturn = scytheCfg.DamageReturn,
		ScytheRange = scytheCfg.Range,
		ScytheInterval = scytheCfg.FireInterval,
		LastScytheTime = 0,

		HasSoulDrain = false,
		SoulDrainDamage = drainCfg.Damage,
		SoulDrainRange = drainCfg.Range,
		SoulDrainHeal = drainCfg.HealPercent,
		SoulDrainTickInterval = drainCfg.TickInterval,
		LastSoulDrainTick = 0,

		HasShockwave = false,
		ShockwaveDamage = shockCfg.Damage,
		ShockwaveRadius = shockCfg.Radius,
		ShockwaveKnockback = shockCfg.KnockbackForce,
		ShockwaveInterval = shockCfg.FireInterval,
		LastShockwaveTime = 0,

		Evolutions = {},
		WeaponLevels = { Orbiter = 1 },
	}
	_weaponStates[player] = state
	return state
end

function CombatService:GetWeaponState(player: Player): WeaponState?
	return _weaponStates[player]
end

function CombatService:GetWeaponLevel(player: Player, weaponId: string): number
	local ws = _weaponStates[player]
	if not ws then
		return 0
	end
	return ws.WeaponLevels[weaponId] or 0
end

-- Apply weapon level scaling bonuses
function CombatService:_applyLevelBonus(player: Player, weaponId: string)
	local ws = _weaponStates[player]
	if not ws then
		return
	end
	local level = ws.WeaponLevels[weaponId] or 1
	if level <= 1 then
		return
	end

	local stats = GameService:GetPlayerStats(player)
	local mult = stats and stats.DamageMultiplier or 1.0
	local lvlCfg = GameConfig.WeaponLevels

	-- Damage scaling: +15% per level for levels 2-3
	-- Cooldown: -10% per level for levels 4-5
	-- Area/range: +20% per level for levels 6-7
	local dmgBonus = 1.0
	local cdBonus = 1.0
	local areaBonus = 1.0

	for _ = 2, math.min(level, 3) do
		dmgBonus += lvlCfg.DamagePerLevel
	end
	for _ = 4, math.min(level, 5) do
		cdBonus *= (1 - lvlCfg.CooldownPerLevel)
	end
	for _ = 6, math.min(level, 7) do
		areaBonus += lvlCfg.AreaPerLevel
	end

	if weaponId == "VoidWhip" then
		ws.VoidWhipDamage = math.floor(GameConfig.Weapons.VoidWhip.Damage * dmgBonus * mult)
		ws.VoidWhipInterval = GameConfig.Weapons.VoidWhip.FireInterval * cdBonus
		ws.VoidWhipRange = GameConfig.Weapons.VoidWhip.Range * areaBonus
	elseif weaponId == "ShadowDaggers" then
		ws.ShadowDaggerDamage = math.floor(GameConfig.Weapons.ShadowDaggers.Damage * dmgBonus * mult)
		ws.ShadowDaggerInterval = GameConfig.Weapons.ShadowDaggers.FireInterval * cdBonus
		if level >= 4 then
			ws.ShadowDaggerCount = GameConfig.Weapons.ShadowDaggers.DaggerCount + (math.min(level, 5) - 3)
		end
	elseif weaponId == "GravityWell" then
		ws.GravityWellDamage = math.floor(GameConfig.Weapons.GravityWell.Damage * dmgBonus * mult)
		ws.GravityWellInterval = GameConfig.Weapons.GravityWell.FireInterval * cdBonus
		ws.GravityWellRadius = GameConfig.Weapons.GravityWell.Radius * areaBonus
	elseif weaponId == "PlagueCloud" then
		ws.PlagueDamage = math.floor(GameConfig.Weapons.PlagueCloud.Damage * dmgBonus * mult)
		ws.PlagueRadius = GameConfig.Weapons.PlagueCloud.Radius * areaBonus
		if level >= 4 then
			ws.PlagueSlow = GameConfig.Weapons.PlagueCloud.SlowPercent + (math.min(level, 5) - 3) * 0.05
		end
	elseif weaponId == "VoidMissiles" then
		ws.MissileDamage = math.floor(GameConfig.Weapons.VoidMissiles.Damage * dmgBonus * mult)
		ws.MissileInterval = GameConfig.Weapons.VoidMissiles.FireInterval * cdBonus
		if level >= 4 then
			ws.MissileCount = GameConfig.Weapons.VoidMissiles.MissileCount + (math.min(level, 5) - 3)
		end
	elseif weaponId == "SpectralScythe" then
		ws.ScytheDamageOut = math.floor(GameConfig.Weapons.SpectralScythe.DamageOut * dmgBonus * mult)
		ws.ScytheDamageReturn = math.floor(GameConfig.Weapons.SpectralScythe.DamageReturn * dmgBonus * mult)
		ws.ScytheInterval = GameConfig.Weapons.SpectralScythe.FireInterval * cdBonus
		ws.ScytheRange = GameConfig.Weapons.SpectralScythe.Range * areaBonus
	elseif weaponId == "SoulDrain" then
		ws.SoulDrainDamage = math.floor(GameConfig.Weapons.SoulDrain.Damage * dmgBonus * mult)
		ws.SoulDrainRange = GameConfig.Weapons.SoulDrain.Range * areaBonus
		if level >= 4 then
			ws.SoulDrainHeal = GameConfig.Weapons.SoulDrain.HealPercent + (math.min(level, 5) - 3) * 0.05
		end
	elseif weaponId == "Shockwave" then
		ws.ShockwaveDamage = math.floor(GameConfig.Weapons.Shockwave.Damage * dmgBonus * mult)
		ws.ShockwaveInterval = GameConfig.Weapons.Shockwave.FireInterval * cdBonus
		ws.ShockwaveRadius = GameConfig.Weapons.Shockwave.Radius * areaBonus
	end
end

-- Called by GameService when an upgrade card is picked
function CombatService:ApplyWeaponUpgrade(player: Player, upgradeId: string)
	local ws = _weaponStates[player]
	if not ws then
		return
	end

	-- Existing weapon upgrades
	if upgradeId == "NewProjectile" then
		ws.HasProjectile = true
		ws.WeaponLevels["Projectile"] = 1
	elseif upgradeId == "OrbiterCount" then
		ws.OrbiterCount += 1
		ws.WeaponLevels["Orbiter"] = (ws.WeaponLevels["Orbiter"] or 1) + 1
		self:_rebuildOrbiters(player)
	elseif upgradeId == "ProjectilePierce" then
		ws.ProjectilePierce += 1
		ws.WeaponLevels["Projectile"] = (ws.WeaponLevels["Projectile"] or 1) + 1
	elseif upgradeId == "ProjectileSpeed" then
		ws.ProjectileFireInterval *= 0.8
		ws.WeaponLevels["Projectile"] = (ws.WeaponLevels["Projectile"] or 1) + 1
	elseif upgradeId == "NewLightning" then
		ws.HasLightning = true
		ws.WeaponLevels["Lightning"] = 1
	elseif upgradeId == "LightningChain" then
		ws.LightningChainCount += 1
		ws.WeaponLevels["Lightning"] = (ws.WeaponLevels["Lightning"] or 1) + 1
	elseif upgradeId == "NewAura" then
		ws.HasAura = true
		ws.WeaponLevels["Aura"] = 1
		self:_rebuildAura(player)
	elseif upgradeId == "AuraRadius" then
		ws.AuraRadius *= 1.3
		ws.WeaponLevels["Aura"] = (ws.WeaponLevels["Aura"] or 1) + 1
		self:_rebuildAura(player)
	elseif upgradeId == "AuraDamage" then
		ws.WeaponLevels["Aura"] = (ws.WeaponLevels["Aura"] or 1) + 1
		-- Damage recalculated in UpdateDamage()
		-- New weapon acquisition
	elseif upgradeId == "NewVoidWhip" then
		ws.HasVoidWhip = true
		ws.WeaponLevels["VoidWhip"] = 1
	elseif upgradeId == "NewShadowDaggers" then
		ws.HasShadowDaggers = true
		ws.WeaponLevels["ShadowDaggers"] = 1
	elseif upgradeId == "NewGravityWell" then
		ws.HasGravityWell = true
		ws.WeaponLevels["GravityWell"] = 1
	elseif upgradeId == "NewPlagueCloud" then
		ws.HasPlagueCloud = true
		ws.WeaponLevels["PlagueCloud"] = 1
	elseif upgradeId == "NewVoidMissiles" then
		ws.HasVoidMissiles = true
		ws.WeaponLevels["VoidMissiles"] = 1
	elseif upgradeId == "NewSpectralScythe" then
		ws.HasSpectralScythe = true
		ws.WeaponLevels["SpectralScythe"] = 1
	elseif upgradeId == "NewSoulDrain" then
		ws.HasSoulDrain = true
		ws.WeaponLevels["SoulDrain"] = 1
	elseif upgradeId == "NewShockwave" then
		ws.HasShockwave = true
		ws.WeaponLevels["Shockwave"] = 1
	-- New weapon level-up cards
	elseif upgradeId == "VoidWhipUp" then
		ws.WeaponLevels["VoidWhip"] = (ws.WeaponLevels["VoidWhip"] or 1) + 1
		self:_applyLevelBonus(player, "VoidWhip")
	elseif upgradeId == "ShadowDaggersUp" then
		ws.WeaponLevels["ShadowDaggers"] = (ws.WeaponLevels["ShadowDaggers"] or 1) + 1
		self:_applyLevelBonus(player, "ShadowDaggers")
	elseif upgradeId == "GravityWellUp" then
		ws.WeaponLevels["GravityWell"] = (ws.WeaponLevels["GravityWell"] or 1) + 1
		self:_applyLevelBonus(player, "GravityWell")
	elseif upgradeId == "PlagueCloudUp" then
		ws.WeaponLevels["PlagueCloud"] = (ws.WeaponLevels["PlagueCloud"] or 1) + 1
		self:_applyLevelBonus(player, "PlagueCloud")
	elseif upgradeId == "VoidMissilesUp" then
		ws.WeaponLevels["VoidMissiles"] = (ws.WeaponLevels["VoidMissiles"] or 1) + 1
		self:_applyLevelBonus(player, "VoidMissiles")
	elseif upgradeId == "SpectralScytheUp" then
		ws.WeaponLevels["SpectralScythe"] = (ws.WeaponLevels["SpectralScythe"] or 1) + 1
		self:_applyLevelBonus(player, "SpectralScythe")
	elseif upgradeId == "SoulDrainUp" then
		ws.WeaponLevels["SoulDrain"] = (ws.WeaponLevels["SoulDrain"] or 1) + 1
		self:_applyLevelBonus(player, "SoulDrain")
	elseif upgradeId == "ShockwaveUp" then
		ws.WeaponLevels["Shockwave"] = (ws.WeaponLevels["Shockwave"] or 1) + 1
		self:_applyLevelBonus(player, "Shockwave")
	end
end

-- Called by GameService when DamageMultiplier changes
function CombatService:UpdateDamage(player: Player)
	local ws = _weaponStates[player]
	if not ws then
		return
	end
	local stats = GameService:GetPlayerStats(player)
	if not stats then
		return
	end
	local mult = stats.DamageMultiplier
	ws.OrbiterDamage = math.floor(GameConfig.Weapons.Orbiter.Damage * mult)
	ws.ProjectileDamage = math.floor(GameConfig.Weapons.Projectile.Damage * mult)
	ws.LightningDamage = math.floor(GameConfig.Weapons.Lightning.Damage * mult)

	-- Aura damage must include AuraDamage upgrade stacks (1.4x per stack)
	local auraDmgStacks = 0
	if stats.Upgrades then
		auraDmgStacks = stats.Upgrades["AuraDamage"] or 0
	end
	ws.AuraDamage = math.floor(GameConfig.Weapons.Aura.Damage * mult * (1.4 ^ auraDmgStacks))

	-- New weapons: re-apply level bonuses (which also apply damage mult)
	for _, weaponId in
		{
			"VoidWhip",
			"ShadowDaggers",
			"GravityWell",
			"PlagueCloud",
			"VoidMissiles",
			"SpectralScythe",
			"SoulDrain",
			"Shockwave",
		}
	do
		if ws.WeaponLevels[weaponId] then
			self:_applyLevelBonus(player, weaponId)
		end
	end
end

-- Check if an evolution is available for this player
function CombatService:GetAvailableEvolution(player: Player): any?
	local ws = _weaponStates[player]
	if not ws then
		return nil
	end
	local maxLevel = GameConfig.WeaponLevels.MaxLevel

	-- EvolutionMaster relic: reduce required level
	local evoMaster = 0
	if StatsService then
		evoMaster = StatsService:GetRelicLevels(player)["EvolutionMaster"] or 0
	end
	local requiredLevel = math.max(1, maxLevel - evoMaster)

	for _, evo in GameConfig.Evolutions do
		if ws.Evolutions[evo.Id] then
			continue
		end
		local a = evo.Ingredients[1]
		local b = evo.Ingredients[2]
		if (ws.WeaponLevels[a] or 0) >= requiredLevel and (ws.WeaponLevels[b] or 0) >= requiredLevel then
			return evo
		end
	end
	return nil
end

-- Apply evolution: replaces both ingredient weapons
function CombatService:ApplyEvolution(player: Player, evolutionId: string): boolean
	local ws = _weaponStates[player]
	if not ws then
		return false
	end

	local evoDef: any = nil
	for _, evo in GameConfig.Evolutions do
		if evo.Id == evolutionId then
			evoDef = evo
			break
		end
	end
	if not evoDef then
		return false
	end

	-- Verify both ingredients are maxed
	local maxLevel = GameConfig.WeaponLevels.MaxLevel
	local a = evoDef.Ingredients[1]
	local b = evoDef.Ingredients[2]
	if (ws.WeaponLevels[a] or 0) < maxLevel or (ws.WeaponLevels[b] or 0) < maxLevel then
		return false
	end

	-- Disable ingredient weapons
	self:_disableWeapon(ws, a)
	self:_disableWeapon(ws, b)

	-- Enable evolution
	ws.Evolutions[evolutionId] = true
	ws.WeaponLevels[evolutionId] = 1

	self.Client.EvolutionActivated:FireAll(evolutionId)
	return true
end

function CombatService:_disableWeapon(ws: WeaponState, weaponId: string)
	if weaponId == "Orbiter" then
		ws.HasOrbiter = false
	elseif weaponId == "Projectile" then
		ws.HasProjectile = false
	elseif weaponId == "Lightning" then
		ws.HasLightning = false
	elseif weaponId == "Aura" then
		ws.HasAura = false
	elseif weaponId == "VoidWhip" then
		ws.HasVoidWhip = false
	elseif weaponId == "ShadowDaggers" then
		ws.HasShadowDaggers = false
	elseif weaponId == "GravityWell" then
		ws.HasGravityWell = false
	elseif weaponId == "PlagueCloud" then
		ws.HasPlagueCloud = false
	elseif weaponId == "VoidMissiles" then
		ws.HasVoidMissiles = false
	elseif weaponId == "SpectralScythe" then
		ws.HasSpectralScythe = false
	elseif weaponId == "SoulDrain" then
		ws.HasSoulDrain = false
	elseif weaponId == "Shockwave" then
		ws.HasShockwave = false
	end
end

-------------------------------------------------
-- ORBITERS
-------------------------------------------------

function CombatService:_rebuildOrbiters(player: Player)
	local old = _orbiterParts[player]
	if old then
		for _, p in old do
			if p and p.Parent then
				p:Destroy()
			end
		end
	end

	local ws = _weaponStates[player]
	if not ws or not ws.HasOrbiter then
		_orbiterParts[player] = {}
		return
	end

	local parts: { BasePart } = {}
	local cfg = GameConfig.Weapons.Orbiter

	for i = 1, ws.OrbiterCount do
		local orb = Instance.new("Part")
		orb.Name = "Orbiter_" .. i
		orb.Shape = Enum.PartType.Ball
		orb.Size = Vector3.one * cfg.SphereSize
		orb.Color = cfg.Color
		orb.Material = Enum.Material.Neon
		orb.Anchored = true
		orb.CanCollide = false
		orb.CastShadow = false
		orb.Position = Vector3.new(0, -100, 0)

		local att0 = Instance.new("Attachment")
		att0.Position = Vector3.new(0, 0, -cfg.SphereSize * 0.3)
		att0.Parent = orb
		local att1 = Instance.new("Attachment")
		att1.Position = Vector3.new(0, 0, cfg.SphereSize * 0.3)
		att1.Parent = orb
		local trail = Instance.new("Trail")
		trail.Attachment0 = att0
		trail.Attachment1 = att1
		trail.Lifetime = 0.3
		trail.MinLength = 0.1
		trail.Color = ColorSequence.new(cfg.Color)
		trail.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
		trail.Parent = orb

		orb.Parent = workspace
		table.insert(parts, orb)
	end

	_orbiterParts[player] = parts
end

local _lastOrbiterCleanup: number = 0

function CombatService:_updateOrbiters(dt: number)
	local orbCfg = GameConfig.Weapons.Orbiter
	local now = tick()

	if (now - _lastOrbiterCleanup) >= 5 then
		_lastOrbiterCleanup = now
		for _, ws in _weaponStates do
			for model in ws.OrbiterHitTimers do
				if not model or not model.Parent then
					ws.OrbiterHitTimers[model] = nil
				end
			end
		end
	end

	for player, ws in _weaponStates do
		if not ws.HasOrbiter then
			continue
		end

		local char = player.Character
		if not char then
			continue
		end
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end

		local stats = GameService:GetPlayerStats(player)
		if not stats or stats.Health <= 0 then
			continue
		end

		local center = root.Position
		ws.OrbiterAngle += orbCfg.OrbitSpeed * dt

		local parts = _orbiterParts[player]
		if not parts then
			continue
		end

		local angleStep = (math.pi * 2) / ws.OrbiterCount

		for i, orb in parts do
			if not orb or not orb.Parent then
				continue
			end

			local angle = ws.OrbiterAngle + (i - 1) * angleStep
			local orbPos = center
				+ Vector3.new(math.cos(angle) * orbCfg.OrbitRadius, 0, math.sin(angle) * orbCfg.OrbitRadius)
			orb.Position = orbPos

			local enemies = EnemyService:GetEnemiesInRadius(orbPos, orbCfg.SphereSize)
			for _, enemy in enemies do
				if not enemy.Alive then
					continue
				end
				local lastHit = ws.OrbiterHitTimers[enemy.Model] or 0
				if (now - lastHit) >= orbCfg.HitCooldown then
					ws.OrbiterHitTimers[enemy.Model] = now
					EnemyService:DamageEnemy(enemy, ws.OrbiterDamage, player)
				end
			end
		end
	end
end

-------------------------------------------------
-- PROJECTILES
-------------------------------------------------

local _activeProjectiles: {
	{
		Part: BasePart,
		Direction: Vector3,
		Speed: number,
		Damage: number,
		Owner: Player,
		PierceLeft: number,
		DistanceTraveled: number,
		MaxRange: number,
		HitEnemies: { [Model]: boolean },
	}
} =
	{}

function CombatService:_updateProjectiles(dt: number)
	local projCfg = GameConfig.Weapons.Projectile
	local now = tick()

	for player, ws in _weaponStates do
		if not ws.HasProjectile then
			continue
		end

		local stats = GameService:GetPlayerStats(player)
		if not stats or stats.Health <= 0 then
			continue
		end

		if (now - ws.LastProjectileTime) < ws.ProjectileFireInterval then
			continue
		end

		local char = player.Character
		if not char then
			continue
		end
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end

		local pos = root.Position
		local closestEnemy: any = nil
		local closestDist = projCfg.Range

		local nearbyEnemies = EnemyService:GetEnemiesInRadius(pos, projCfg.Range)
		for _, enemy in nearbyEnemies do
			if enemy.Alive and enemy.Model.PrimaryPart then
				local d = (enemy.Model.PrimaryPart.Position - pos).Magnitude
				if d < closestDist then
					closestDist = d
					closestEnemy = enemy
				end
			end
		end

		if not closestEnemy then
			continue
		end

		ws.LastProjectileTime = now

		local targetPos = closestEnemy.Model.PrimaryPart.Position
		local dir = (targetPos - pos).Unit

		local bullet = Instance.new("Part")
		bullet.Name = "Projectile"
		bullet.Size = projCfg.BulletSize
		bullet.Color = projCfg.Color
		bullet.Material = Enum.Material.Neon
		bullet.Anchored = true
		bullet.CanCollide = false
		bullet.CastShadow = false
		bullet.CFrame = CFrame.lookAt(pos + dir * 3, pos + dir * 4)

		local bAtt0 = Instance.new("Attachment")
		bAtt0.Position = Vector3.new(0, 0, -projCfg.BulletSize.Z * 0.5)
		bAtt0.Parent = bullet
		local bAtt1 = Instance.new("Attachment")
		bAtt1.Position = Vector3.new(0, 0, projCfg.BulletSize.Z * 0.5)
		bAtt1.Parent = bullet
		local bTrail = Instance.new("Trail")
		bTrail.Attachment0 = bAtt0
		bTrail.Attachment1 = bAtt1
		bTrail.Lifetime = 0.2
		bTrail.MinLength = 0.1
		bTrail.Color = ColorSequence.new(projCfg.Color)
		bTrail.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		bTrail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.3) })
		bTrail.Parent = bullet

		bullet.Parent = _projectileFolder

		table.insert(_activeProjectiles, {
			Part = bullet,
			Direction = dir,
			Speed = projCfg.Speed,
			Damage = ws.ProjectileDamage,
			Owner = player,
			PierceLeft = ws.ProjectilePierce,
			DistanceTraveled = 0,
			MaxRange = projCfg.Range,
			HitEnemies = {},
		})

		self.Client.ProjectileFired:FireAll(pos, dir)
	end

	local toRemove: { number } = {}
	for i, proj in _activeProjectiles do
		if not proj.Part or not proj.Part.Parent then
			table.insert(toRemove, i)
			continue
		end

		local move = proj.Direction * proj.Speed * dt
		proj.Part.Position += move
		proj.DistanceTraveled += move.Magnitude

		local enemies = EnemyService:GetEnemiesInRadius(proj.Part.Position, 2.5)
		for _, enemy in enemies do
			if enemy.Alive and not proj.HitEnemies[enemy.Model] then
				proj.HitEnemies[enemy.Model] = true
				EnemyService:DamageEnemy(enemy, proj.Damage, proj.Owner)
				proj.PierceLeft -= 1
				if proj.PierceLeft <= 0 then
					break
				end
			end
		end

		if proj.PierceLeft <= 0 or proj.DistanceTraveled >= proj.MaxRange then
			table.insert(toRemove, i)
		end
	end

	for i = #toRemove, 1, -1 do
		local idx = toRemove[i]
		local proj = _activeProjectiles[idx]
		if proj.Part and proj.Part.Parent then
			if proj.PierceLeft <= 0 then
				self.Client.ProjectileImpact:FireAll(proj.Part.Position)
			end
			proj.Part:Destroy()
		end
		table.remove(_activeProjectiles, idx)
	end
end

-------------------------------------------------
-- LIGHTNING
-------------------------------------------------

function CombatService:_updateLightning(_dt: number)
	local now = tick()

	for player, ws in _weaponStates do
		if not ws.HasLightning then
			continue
		end

		local stats = GameService:GetPlayerStats(player)
		if not stats or stats.Health <= 0 then
			continue
		end

		if (now - ws.LastLightningTime) < ws.LightningFireInterval then
			continue
		end

		local char = player.Character
		if not char then
			continue
		end
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end

		local pos = root.Position
		local closestEnemy: any = nil
		local closestDist = ws.LightningRange

		local nearbyEnemies = EnemyService:GetEnemiesInRadius(pos, ws.LightningRange)
		for _, enemy in nearbyEnemies do
			if enemy.Alive and enemy.Model.PrimaryPart then
				local d = (enemy.Model.PrimaryPart.Position - pos).Magnitude
				if d < closestDist then
					closestDist = d
					closestEnemy = enemy
				end
			end
		end

		if not closestEnemy then
			continue
		end

		ws.LastLightningTime = now

		local targetPos = closestEnemy.Model.PrimaryPart.Position
		EnemyService:DamageEnemy(closestEnemy, ws.LightningDamage, player)

		local chainPositions: { Vector3 } = { targetPos }
		local hitEnemies: { [any]: boolean } = { [closestEnemy] = true }
		local lastChainPos = targetPos

		for _ = 1, ws.LightningChainCount do
			local chainTarget: any = nil
			local chainDist = ws.LightningChainRange

			local chainNearby = EnemyService:GetEnemiesInRadius(lastChainPos, ws.LightningChainRange)
			for _, enemy in chainNearby do
				if enemy.Alive and not hitEnemies[enemy] and enemy.Model.PrimaryPart then
					local d = (enemy.Model.PrimaryPart.Position - lastChainPos).Magnitude
					if d < chainDist then
						chainDist = d
						chainTarget = enemy
					end
				end
			end

			if not chainTarget then
				break
			end

			hitEnemies[chainTarget] = true
			local chainPos = chainTarget.Model.PrimaryPart.Position
			table.insert(chainPositions, chainPos)
			EnemyService:DamageEnemy(chainTarget, ws.LightningDamage, player)
			lastChainPos = chainPos
		end

		self.Client.LightningFired:FireAll(pos, targetPos, chainPositions)
	end
end

-------------------------------------------------
-- AURA
-------------------------------------------------

function CombatService:_rebuildAura(player: Player)
	local old = _auraParts[player]
	if old and old.Parent then
		old:Destroy()
	end

	local ws = _weaponStates[player]
	if not ws or not ws.HasAura then
		_auraParts[player] = nil
		return
	end

	local auraCfg = GameConfig.Weapons.Aura
	local ring = Instance.new("Part")
	ring.Name = "AuraRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, ws.AuraRadius * 2, ws.AuraRadius * 2)
	ring.Color = auraCfg.Color
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.7
	ring.Anchored = true
	ring.CanCollide = false
	ring.CastShadow = false
	ring.Position = Vector3.new(0, -100, 0)
	ring.Parent = workspace

	_auraParts[player] = ring
end

function CombatService:_updateAura(_dt: number)
	local now = tick()

	for player, ws in _weaponStates do
		if not ws.HasAura then
			continue
		end

		local char = player.Character
		if not char then
			continue
		end
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end

		local stats = GameService:GetPlayerStats(player)
		if not stats or stats.Health <= 0 then
			continue
		end

		local pos = root.Position

		local ring = _auraParts[player]
		if ring and ring.Parent then
			local pulse = math.sin(now * 3)
			local scaleFactor = 1.0 + pulse * 0.05
			local diameter = ws.AuraRadius * 2 * scaleFactor
			ring.Size = Vector3.new(0.3, diameter, diameter)
			ring.Transparency = 0.6 + pulse * 0.1
			ring.CFrame = CFrame.new(pos.X, pos.Y - 1, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
		end

		if (now - ws.LastAuraTickTime) < ws.AuraTickInterval then
			continue
		end
		ws.LastAuraTickTime = now

		local enemies = EnemyService:GetEnemiesInRadius(pos, ws.AuraRadius)
		for _, enemy in enemies do
			if enemy.Alive then
				EnemyService:DamageEnemy(enemy, ws.AuraDamage, player)
			end
		end
	end
end

-------------------------------------------------
-- VOID WHIP (120° arc melee sweep)
-------------------------------------------------

function CombatService:_updateVoidWhip(_dt: number)
	local now = tick()

	for player, ws in _weaponStates do
		if not ws.HasVoidWhip then
			continue
		end

		local stats = GameService:GetPlayerStats(player)
		if not stats or stats.Health <= 0 then
			continue
		end

		if (now - ws.LastVoidWhipTime) < ws.VoidWhipInterval then
			continue
		end

		local char = player.Character
		if not char then
			continue
		end
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end

		-- Find nearest enemy to determine whip direction
		local pos = root.Position
		local closestEnemy: any = nil
		local closestDist = ws.VoidWhipRange

		local nearbyEnemies = EnemyService:GetEnemiesInRadius(pos, ws.VoidWhipRange)
		for _, enemy in nearbyEnemies do
			if enemy.Alive and enemy.Model.PrimaryPart then
				local d = (enemy.Model.PrimaryPart.Position - pos).Magnitude
				if d < closestDist then
					closestDist = d
					closestEnemy = enemy
				end
			end
		end

		if not closestEnemy then
			continue
		end

		ws.LastVoidWhipTime = now

		local targetPos = closestEnemy.Model.PrimaryPart.Position
		local dir = (targetPos - pos).Unit
		local halfArc = math.rad(ws.VoidWhipArc / 2)

		-- Damage all enemies in the arc
		for _, enemy in nearbyEnemies do
			if not enemy.Alive or not enemy.Model.PrimaryPart then
				continue
			end
			local toEnemy = (enemy.Model.PrimaryPart.Position - pos).Unit
			local angle = math.acos(math.clamp(dir:Dot(toEnemy), -1, 1))
			if angle <= halfArc then
				EnemyService:DamageEnemy(enemy, ws.VoidWhipDamage, player)
			end
		end

		self.Client.WhipSlash:FireAll(pos, dir, ws.VoidWhipArc)
	end
end

-------------------------------------------------
-- SHADOW DAGGERS (multi-projectile spread)
-------------------------------------------------

function CombatService:_updateShadowDaggers(_dt: number)
	local daggerCfg = GameConfig.Weapons.ShadowDaggers
	local now = tick()

	for player, ws in _weaponStates do
		if not ws.HasShadowDaggers then
			continue
		end

		local stats = GameService:GetPlayerStats(player)
		if not stats or stats.Health <= 0 then
			continue
		end

		if (now - ws.LastShadowDaggerTime) < ws.ShadowDaggerInterval then
			continue
		end

		local char = player.Character
		if not char then
			continue
		end
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end

		local pos = root.Position
		local closestEnemy: any = nil
		local closestDist = daggerCfg.Range

		local nearbyEnemies = EnemyService:GetEnemiesInRadius(pos, daggerCfg.Range)
		for _, enemy in nearbyEnemies do
			if enemy.Alive and enemy.Model.PrimaryPart then
				local d = (enemy.Model.PrimaryPart.Position - pos).Magnitude
				if d < closestDist then
					closestDist = d
					closestEnemy = enemy
				end
			end
		end

		if not closestEnemy then
			continue
		end

		ws.LastShadowDaggerTime = now

		local targetPos = closestEnemy.Model.PrimaryPart.Position
		local baseDir = (targetPos - pos).Unit
		local spreadRad = math.rad(daggerCfg.SpreadAngle)
		local directions: { Vector3 } = {}

		for i = 1, ws.ShadowDaggerCount do
			local offset = (i - (ws.ShadowDaggerCount + 1) / 2) * spreadRad / ws.ShadowDaggerCount
			local rotated = CFrame.new(Vector3.zero, baseDir) * CFrame.Angles(0, offset, 0)
			local dir = rotated.LookVector
			table.insert(directions, dir)

			local bullet = Instance.new("Part")
			bullet.Name = "ShadowDagger"
			bullet.Size = daggerCfg.BulletSize
			bullet.Color = daggerCfg.Color
			bullet.Material = Enum.Material.Neon
			bullet.Anchored = true
			bullet.CanCollide = false
			bullet.CastShadow = false
			bullet.CFrame = CFrame.lookAt(pos + dir * 3, pos + dir * 4)
			bullet.Parent = _projectileFolder

			table.insert(_activeProjectiles, {
				Part = bullet,
				Direction = dir,
				Speed = daggerCfg.Speed,
				Damage = ws.ShadowDaggerDamage,
				Owner = player,
				PierceLeft = 1,
				DistanceTraveled = 0,
				MaxRange = daggerCfg.Range,
				HitEnemies = {},
			})
		end

		self.Client.DaggersFired:FireAll(pos, directions)
	end
end

-------------------------------------------------
-- GRAVITY WELL (placed AoE pull + tick damage)
-------------------------------------------------

type GravityWellInstance = {
	Position: Vector3,
	Radius: number,
	Damage: number,
	PullSpeed: number,
	Owner: Player,
	ExpiresAt: number,
	LastTickTime: number,
}

local _activeGravityWells: { GravityWellInstance } = {}

function CombatService:_updateGravityWells(dt: number)
	local now = tick()

	-- Fire new wells
	for player, ws in _weaponStates do
		if not ws.HasGravityWell then
			continue
		end

		local stats = GameService:GetPlayerStats(player)
		if not stats or stats.Health <= 0 then
			continue
		end

		if (now - ws.LastGravityWellTime) < ws.GravityWellInterval then
			continue
		end

		local char = player.Character
		if not char then
			continue
		end
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end

		ws.LastGravityWellTime = now
		local pos = root.Position

		table.insert(_activeGravityWells, {
			Position = pos,
			Radius = ws.GravityWellRadius,
			Damage = ws.GravityWellDamage,
			PullSpeed = GameConfig.Weapons.GravityWell.PullSpeed,
			Owner = player,
			ExpiresAt = now + ws.GravityWellDuration,
			LastTickTime = now,
		})

		self.Client.GravityWellPlaced:FireAll(pos, ws.GravityWellRadius, ws.GravityWellDuration)
	end

	-- Update active wells
	local toRemove: { number } = {}
	for i, well in _activeGravityWells do
		if now >= well.ExpiresAt then
			table.insert(toRemove, i)
			continue
		end

		local enemies = EnemyService:GetEnemiesInRadius(well.Position, well.Radius)
		for _, enemy in enemies do
			if not enemy.Alive or not enemy.Model.PrimaryPart then
				continue
			end

			-- Pull toward center
			local toCenter = (well.Position - enemy.Model.PrimaryPart.Position)
			local dist = toCenter.Magnitude
			if dist > 1 then
				local pullDir = toCenter.Unit
				local align = enemy.Model.PrimaryPart:FindFirstChildOfClass("AlignPosition") :: AlignPosition?
				if align then
					align.Position = enemy.Model.PrimaryPart.Position + pullDir * well.PullSpeed * dt
				end
			end
		end

		-- Tick damage every 0.5s
		if (now - well.LastTickTime) >= 0.5 then
			well.LastTickTime = now
			local enemies2 = EnemyService:GetEnemiesInRadius(well.Position, well.Radius)
			for _, enemy in enemies2 do
				if enemy.Alive then
					EnemyService:DamageEnemy(enemy, well.Damage, well.Owner)
				end
			end
		end
	end

	for i = #toRemove, 1, -1 do
		table.remove(_activeGravityWells, toRemove[i])
	end
end

-------------------------------------------------
-- PLAGUE CLOUD (DoT AoE follows player + slow)
-------------------------------------------------

function CombatService:_updatePlagueCloud(_dt: number)
	local now = tick()

	for player, ws in _weaponStates do
		if not ws.HasPlagueCloud then
			continue
		end

		local stats = GameService:GetPlayerStats(player)
		if not stats or stats.Health <= 0 then
			continue
		end

		if (now - ws.LastPlagueTickTime) < ws.PlagueTickInterval then
			continue
		end
		ws.LastPlagueTickTime = now

		local char = player.Character
		if not char then
			continue
		end
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end

		local pos = root.Position
		local enemies = EnemyService:GetEnemiesInRadius(pos, ws.PlagueRadius)
		for _, enemy in enemies do
			if enemy.Alive then
				EnemyService:DamageEnemy(enemy, ws.PlagueDamage, player)
				-- Apply slow by reducing AlignPosition MaxVelocity
				if enemy.Model and enemy.Model.PrimaryPart then
					local align = enemy.Model.PrimaryPart:FindFirstChildOfClass("AlignPosition") :: AlignPosition?
					if align then
						local baseSpeed = enemy.Speed or 10
						align.MaxVelocity = baseSpeed * (1 - ws.PlagueSlow)
					end
				end
			end
		end
	end
end

-------------------------------------------------
-- VOID MISSILES (homing)
-------------------------------------------------

type MissileInstance = {
	Part: BasePart,
	Direction: Vector3,
	Speed: number,
	Damage: number,
	Owner: Player,
	Target: any, -- EnemyData
	DistanceTraveled: number,
	MaxRange: number,
}

local _activeMissiles: { MissileInstance } = {}

function CombatService:_updateVoidMissiles(dt: number)
	local missileCfg = GameConfig.Weapons.VoidMissiles
	local now = tick()

	-- Fire new missiles
	for player, ws in _weaponStates do
		if not ws.HasVoidMissiles then
			continue
		end

		local stats = GameService:GetPlayerStats(player)
		if not stats or stats.Health <= 0 then
			continue
		end

		if (now - ws.LastMissileTime) < ws.MissileInterval then
			continue
		end

		local char = player.Character
		if not char then
			continue
		end
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end

		local pos = root.Position
		local nearbyEnemies = EnemyService:GetEnemiesInRadius(pos, missileCfg.Range)
		if #nearbyEnemies == 0 then
			continue
		end

		ws.LastMissileTime = now

		-- Sort by distance to pick different targets for each missile
		table.sort(nearbyEnemies, function(a, b)
			local aDist = a.Model.PrimaryPart and (a.Model.PrimaryPart.Position - pos).Magnitude or 999
			local bDist = b.Model.PrimaryPart and (b.Model.PrimaryPart.Position - pos).Magnitude or 999
			return aDist < bDist
		end)

		local positions: { Vector3 } = {}
		local directions: { Vector3 } = {}
		for m = 1, ws.MissileCount do
			local targetIdx = math.min(m, #nearbyEnemies)
			local target = nearbyEnemies[targetIdx]
			if not target or not target.Model.PrimaryPart then
				continue
			end

			local dir = (target.Model.PrimaryPart.Position - pos).Unit
			table.insert(positions, pos)
			table.insert(directions, dir)

			local missile = Instance.new("Part")
			missile.Name = "VoidMissile"
			missile.Size = missileCfg.BulletSize
			missile.Color = missileCfg.Color
			missile.Material = Enum.Material.Neon
			missile.Anchored = true
			missile.CanCollide = false
			missile.CastShadow = false
			missile.CFrame = CFrame.lookAt(pos + dir * 3, pos + dir * 4)
			missile.Parent = _projectileFolder

			table.insert(_activeMissiles, {
				Part = missile,
				Direction = dir,
				Speed = missileCfg.Speed,
				Damage = ws.MissileDamage,
				Owner = player,
				Target = target,
				DistanceTraveled = 0,
				MaxRange = missileCfg.Range,
			})
		end

		if #positions > 0 then
			self.Client.MissilesFired:FireAll(positions, directions)
		end
	end

	-- Move existing missiles with homing
	local toRemove: { number } = {}
	for i, m in _activeMissiles do
		if not m.Part or not m.Part.Parent then
			table.insert(toRemove, i)
			continue
		end

		-- Home toward target if still alive
		if m.Target and m.Target.Alive and m.Target.Model and m.Target.Model.PrimaryPart then
			local desiredDir = (m.Target.Model.PrimaryPart.Position - m.Part.Position).Unit
			m.Direction = m.Direction:Lerp(desiredDir, math.min(1, missileCfg.TurnSpeed * dt))
		end

		local move = m.Direction * m.Speed * dt
		m.Part.Position += move
		m.Part.CFrame = CFrame.lookAt(m.Part.Position, m.Part.Position + m.Direction)
		m.DistanceTraveled += move.Magnitude

		-- Check hits
		local enemies = EnemyService:GetEnemiesInRadius(m.Part.Position, 3)
		local hit = false
		for _, enemy in enemies do
			if enemy.Alive then
				EnemyService:DamageEnemy(enemy, m.Damage, m.Owner)
				hit = true
				break
			end
		end

		if hit or m.DistanceTraveled >= m.MaxRange then
			table.insert(toRemove, i)
		end
	end

	for i = #toRemove, 1, -1 do
		local idx = toRemove[i]
		local m = _activeMissiles[idx]
		if m.Part and m.Part.Parent then
			m.Part:Destroy()
		end
		table.remove(_activeMissiles, idx)
	end
end

-------------------------------------------------
-- SPECTRAL SCYTHE (boomerang)
-------------------------------------------------

type ScytheInstance = {
	Part: BasePart,
	Owner: Player,
	StartPos: Vector3,
	Direction: Vector3,
	Speed: number,
	DamageOut: number,
	DamageReturn: number,
	MaxRange: number,
	DistanceTraveled: number,
	Returning: boolean,
	HitEnemies: { [Model]: boolean },
}

local _activeScythes: { ScytheInstance } = {}

function CombatService:_updateSpectralScythes(dt: number)
	local scytheCfg = GameConfig.Weapons.SpectralScythe
	local now = tick()

	-- Fire new scythes
	for player, ws in _weaponStates do
		if not ws.HasSpectralScythe then
			continue
		end

		local stats = GameService:GetPlayerStats(player)
		if not stats or stats.Health <= 0 then
			continue
		end

		if (now - ws.LastScytheTime) < ws.ScytheInterval then
			continue
		end

		local char = player.Character
		if not char then
			continue
		end
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end

		local pos = root.Position
		local closestEnemy: any = nil
		local closestDist = ws.ScytheRange

		local nearbyEnemies = EnemyService:GetEnemiesInRadius(pos, ws.ScytheRange)
		for _, enemy in nearbyEnemies do
			if enemy.Alive and enemy.Model.PrimaryPart then
				local d = (enemy.Model.PrimaryPart.Position - pos).Magnitude
				if d < closestDist then
					closestDist = d
					closestEnemy = enemy
				end
			end
		end

		if not closestEnemy then
			continue
		end

		ws.LastScytheTime = now
		local targetPos = closestEnemy.Model.PrimaryPart.Position
		local dir = (targetPos - pos).Unit

		local scythe = Instance.new("Part")
		scythe.Name = "SpectralScythe"
		scythe.Size = scytheCfg.Size
		scythe.Color = scytheCfg.Color
		scythe.Material = Enum.Material.Neon
		scythe.Anchored = true
		scythe.CanCollide = false
		scythe.CastShadow = false
		scythe.CFrame = CFrame.new(pos + dir * 3)
		scythe.Parent = _projectileFolder

		table.insert(_activeScythes, {
			Part = scythe,
			Owner = player,
			StartPos = pos,
			Direction = dir,
			Speed = scytheCfg.Speed,
			DamageOut = ws.ScytheDamageOut,
			DamageReturn = ws.ScytheDamageReturn,
			MaxRange = ws.ScytheRange,
			DistanceTraveled = 0,
			Returning = false,
			HitEnemies = {},
		})

		self.Client.ScytheFired:FireAll(pos, dir)
	end

	-- Move scythes
	local toRemove: { number } = {}
	for i, s in _activeScythes do
		if not s.Part or not s.Part.Parent then
			table.insert(toRemove, i)
			continue
		end

		-- Rotate for visual effect
		s.Part.CFrame = s.Part.CFrame * CFrame.Angles(0, dt * 15, 0)

		if not s.Returning then
			-- Outward phase
			local move = s.Direction * s.Speed * dt
			s.Part.Position += move
			s.DistanceTraveled += move.Magnitude

			-- Check hits (outward damage)
			local enemies = EnemyService:GetEnemiesInRadius(s.Part.Position, 3)
			for _, enemy in enemies do
				if enemy.Alive and not s.HitEnemies[enemy.Model] then
					s.HitEnemies[enemy.Model] = true
					EnemyService:DamageEnemy(enemy, s.DamageOut, s.Owner)
				end
			end

			if s.DistanceTraveled >= s.MaxRange then
				s.Returning = true
				s.HitEnemies = {} -- clear so return pass can hit again
			end
		else
			-- Return phase: head toward owner
			local ownerChar = s.Owner.Character
			if not ownerChar then
				table.insert(toRemove, i)
				continue
			end
			local ownerRoot = ownerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not ownerRoot then
				table.insert(toRemove, i)
				continue
			end

			local toOwner = (ownerRoot.Position - s.Part.Position)
			local dist = toOwner.Magnitude
			if dist < 3 then
				table.insert(toRemove, i)
				continue
			end

			local dir = toOwner.Unit
			s.Part.Position += dir * s.Speed * dt

			-- Check hits (return damage)
			local enemies = EnemyService:GetEnemiesInRadius(s.Part.Position, 3)
			for _, enemy in enemies do
				if enemy.Alive and not s.HitEnemies[enemy.Model] then
					s.HitEnemies[enemy.Model] = true
					EnemyService:DamageEnemy(enemy, s.DamageReturn, s.Owner)
				end
			end
		end
	end

	for i = #toRemove, 1, -1 do
		local idx = toRemove[i]
		local s = _activeScythes[idx]
		if s.Part and s.Part.Parent then
			s.Part:Destroy()
		end
		table.remove(_activeScythes, idx)
	end
end

-------------------------------------------------
-- SOUL DRAIN (continuous beam, heals player)
-------------------------------------------------

function CombatService:_updateSoulDrain(_dt: number)
	local now = tick()

	for player, ws in _weaponStates do
		if not ws.HasSoulDrain then
			continue
		end

		local stats = GameService:GetPlayerStats(player)
		if not stats or stats.Health <= 0 then
			continue
		end

		if (now - ws.LastSoulDrainTick) < ws.SoulDrainTickInterval then
			continue
		end
		ws.LastSoulDrainTick = now

		local char = player.Character
		if not char then
			continue
		end
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end

		local pos = root.Position
		local closestEnemy: any = nil
		local closestDist = ws.SoulDrainRange

		local nearbyEnemies = EnemyService:GetEnemiesInRadius(pos, ws.SoulDrainRange)
		for _, enemy in nearbyEnemies do
			if enemy.Alive and enemy.Model.PrimaryPart then
				local d = (enemy.Model.PrimaryPart.Position - pos).Magnitude
				if d < closestDist then
					closestDist = d
					closestEnemy = enemy
				end
			end
		end

		if not closestEnemy then
			continue
		end

		local tickDamage = math.floor(ws.SoulDrainDamage * ws.SoulDrainTickInterval)
		EnemyService:DamageEnemy(closestEnemy, tickDamage, player)

		-- Heal player for % of damage dealt
		local healAmount = math.floor(tickDamage * ws.SoulDrainHeal)
		if healAmount > 0 then
			GameService:HealPlayer(player, healAmount)
		end

		local targetPos = closestEnemy.Model.PrimaryPart.Position
		self.Client.SoulDrainBeam:FireAll(pos, targetPos)
	end
end

-------------------------------------------------
-- SHOCKWAVE (radial burst + knockback)
-------------------------------------------------

function CombatService:_updateShockwave(_dt: number)
	local now = tick()

	for player, ws in _weaponStates do
		if not ws.HasShockwave then
			continue
		end

		local stats = GameService:GetPlayerStats(player)
		if not stats or stats.Health <= 0 then
			continue
		end

		if (now - ws.LastShockwaveTime) < ws.ShockwaveInterval then
			continue
		end

		local char = player.Character
		if not char then
			continue
		end
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end

		-- Only fire if enemies nearby
		local pos = root.Position
		local enemies = EnemyService:GetEnemiesInRadius(pos, ws.ShockwaveRadius)
		if #enemies == 0 then
			continue
		end

		ws.LastShockwaveTime = now

		for _, enemy in enemies do
			if not enemy.Alive then
				continue
			end
			EnemyService:DamageEnemy(enemy, ws.ShockwaveDamage, player)

			-- Knockback
			if enemy.Model and enemy.Model.PrimaryPart then
				local knockDir = (enemy.Model.PrimaryPart.Position - pos)
				if knockDir.Magnitude > 0.1 then
					knockDir = knockDir.Unit
					local align = enemy.Model.PrimaryPart:FindFirstChildOfClass("AlignPosition") :: AlignPosition?
					if align then
						local knockPos = enemy.Model.PrimaryPart.Position + knockDir * ws.ShockwaveKnockback * 0.3
						align.Position = knockPos
					end
				end
			end
		end

		self.Client.ShockwaveBlast:FireAll(pos, ws.ShockwaveRadius)
	end
end

-------------------------------------------------
-- LIFECYCLE
-------------------------------------------------

function CombatService:KnitInit()
	_projectileFolder = Instance.new("Folder")
	_projectileFolder.Name = "Projectiles"
	_projectileFolder.Parent = workspace

	Players.PlayerAdded:Connect(function(player: Player)
		self:_initWeaponState(player)

		player.CharacterAdded:Connect(function(_character)
			self:_rebuildOrbiters(player)
			local ws = _weaponStates[player]
			if ws and ws.HasAura then
				self:_rebuildAura(player)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		local parts = _orbiterParts[player]
		if parts then
			for _, p in parts do
				if p and p.Parent then
					p:Destroy()
				end
			end
		end
		_orbiterParts[player] = nil

		local aura = _auraParts[player]
		if aura and aura.Parent then
			aura:Destroy()
		end
		_auraParts[player] = nil

		_weaponStates[player] = nil
	end)
end

function CombatService:ResetPlayer(player: Player)
	self:_initWeaponState(player)
	self:_rebuildOrbiters(player)
	local oldAura = _auraParts[player]
	if oldAura and oldAura.Parent then
		oldAura:Destroy()
	end
	_auraParts[player] = nil
end

function CombatService:KnitStart()
	GameService = Knit.GetService("GameService")
	EnemyService = Knit.GetService("EnemyService")
	StatsService = Knit.GetService("StatsService")

	RunService.Heartbeat:Connect(function(dt: number)
		self:_updateOrbiters(dt)
		self:_updateProjectiles(dt)
		self:_updateLightning(dt)
		self:_updateAura(dt)
		self:_updateVoidWhip(dt)
		self:_updateShadowDaggers(dt)
		self:_updateGravityWells(dt)
		self:_updatePlagueCloud(dt)
		self:_updateVoidMissiles(dt)
		self:_updateSpectralScythes(dt)
		self:_updateSoulDrain(dt)
		self:_updateShockwave(dt)
	end)
end

return CombatService
