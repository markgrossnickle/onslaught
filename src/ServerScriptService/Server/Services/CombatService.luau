--!strict
--[=[
	Auto-attack weapon system (Vampire Survivors style).
	Weapons fire automatically — player only controls movement.
]=]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local CombatService = Knit.CreateService({
	Name = "CombatService",
	Client = {
		OrbiterSync = Knit.CreateSignal(), -- sync orbiter positions for VFX
		ProjectileFired = Knit.CreateSignal(),
		LightningFired = Knit.CreateSignal(), -- (startPos, endPos, chainPositions)
		AuraSync = Knit.CreateSignal(), -- (playerPos, radius)
	},
})

local GameService: any
local EnemyService: any

-- Per-player weapon state
export type WeaponState = {
	HasOrbiter: boolean,
	OrbiterCount: number,
	OrbiterDamage: number,
	OrbiterAngle: number, -- current rotation angle
	OrbiterHitTimers: { [Model]: number }, -- per-enemy hit cooldowns

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
}

local _weaponStates: { [Player]: WeaponState } = {}
local _orbiterParts: { [Player]: { BasePart } } = {}
local _auraParts: { [Player]: BasePart } = {}
local _projectileFolder: Folder = nil :: any

function CombatService:_initWeaponState(player: Player): WeaponState
	local cfg = GameConfig.Weapons.Orbiter
	local lightCfg = GameConfig.Weapons.Lightning
	local auraCfg = GameConfig.Weapons.Aura
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
	}
	_weaponStates[player] = state
	return state
end

function CombatService:GetWeaponState(player: Player): WeaponState?
	return _weaponStates[player]
end

-- Called by GameService when an upgrade card is picked
function CombatService:ApplyWeaponUpgrade(player: Player, upgradeId: string)
	local ws = _weaponStates[player]
	if not ws then
		return
	end

	if upgradeId == "NewProjectile" then
		ws.HasProjectile = true
	elseif upgradeId == "OrbiterCount" then
		ws.OrbiterCount += 1
		self:_rebuildOrbiters(player)
	elseif upgradeId == "ProjectilePierce" then
		ws.ProjectilePierce += 1
	elseif upgradeId == "ProjectileSpeed" then
		ws.ProjectileFireInterval *= 0.8
	elseif upgradeId == "NewLightning" then
		ws.HasLightning = true
	elseif upgradeId == "LightningChain" then
		ws.LightningChainCount += 1
	elseif upgradeId == "NewAura" then
		ws.HasAura = true
		self:_rebuildAura(player)
	elseif upgradeId == "AuraRadius" then
		ws.AuraRadius *= 1.3
		self:_rebuildAura(player)
	elseif upgradeId == "AuraDamage" then
		ws.AuraDamage = math.floor(ws.AuraDamage * 1.4)
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
	ws.OrbiterDamage = math.floor(GameConfig.Weapons.Orbiter.Damage * stats.DamageMultiplier)
	ws.ProjectileDamage = math.floor(GameConfig.Weapons.Projectile.Damage * stats.DamageMultiplier)
	ws.LightningDamage = math.floor(GameConfig.Weapons.Lightning.Damage * stats.DamageMultiplier)
	ws.AuraDamage = math.floor(GameConfig.Weapons.Aura.Damage * stats.DamageMultiplier)
end

-------------------------------------------------
-- ORBITERS
-------------------------------------------------

function CombatService:_rebuildOrbiters(player: Player)
	-- Destroy old orbiters
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
		orb.Position = Vector3.new(0, -100, 0) -- offscreen until positioned
		orb.Parent = workspace
		table.insert(parts, orb)
	end

	_orbiterParts[player] = parts
end

function CombatService:_updateOrbiters(dt: number)
	local orbCfg = GameConfig.Weapons.Orbiter
	local now = tick()

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

			-- Check hits against enemies
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

	-- Fire new projectiles
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

		-- Find nearest enemy to aim at
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

		-- Create bullet
		local bullet = Instance.new("Part")
		bullet.Name = "Projectile"
		bullet.Size = projCfg.BulletSize
		bullet.Color = projCfg.Color
		bullet.Material = Enum.Material.Neon
		bullet.Anchored = true
		bullet.CanCollide = false
		bullet.CastShadow = false
		bullet.CFrame = CFrame.lookAt(pos + dir * 3, pos + dir * 4)
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

	-- Move existing projectiles
	local toRemove: { number } = {}
	for i, proj in _activeProjectiles do
		if not proj.Part or not proj.Part.Parent then
			table.insert(toRemove, i)
			continue
		end

		local move = proj.Direction * proj.Speed * dt
		proj.Part.Position += move
		proj.DistanceTraveled += move.Magnitude

		-- Check hits
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

	-- Remove spent projectiles (iterate backwards)
	for i = #toRemove, 1, -1 do
		local idx = toRemove[i]
		local proj = _activeProjectiles[idx]
		if proj.Part and proj.Part.Parent then
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

		-- Find nearest enemy
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

		-- Damage primary target
		local targetPos = closestEnemy.Model.PrimaryPart.Position
		EnemyService:DamageEnemy(closestEnemy, ws.LightningDamage, player)

		-- Build chain positions for VFX
		local chainPositions: { Vector3 } = { targetPos }
		local hitEnemies: { [any]: boolean } = { [closestEnemy] = true }
		local lastChainPos = targetPos

		-- Chain to additional enemies
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

		-- Notify clients for VFX
		self.Client.LightningFired:FireAll(pos, targetPos, chainPositions)
	end
end

-------------------------------------------------
-- AURA
-------------------------------------------------

function CombatService:_rebuildAura(player: Player)
	-- Destroy old aura part
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
	ring.Position = Vector3.new(0, -100, 0) -- offscreen until positioned
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

		-- Position the aura ring at the player
		local ring = _auraParts[player]
		if ring and ring.Parent then
			ring.Size = Vector3.new(0.3, ws.AuraRadius * 2, ws.AuraRadius * 2)
			-- Cylinder needs rotation so it lies flat on the ground
			ring.CFrame = CFrame.new(pos.X, pos.Y - 1, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
		end

		-- Tick damage
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
		-- Clean up orbiters
		local parts = _orbiterParts[player]
		if parts then
			for _, p in parts do
				if p and p.Parent then
					p:Destroy()
				end
			end
		end
		_orbiterParts[player] = nil

		-- Clean up aura
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
	-- Destroy old aura
	local oldAura = _auraParts[player]
	if oldAura and oldAura.Parent then
		oldAura:Destroy()
	end
	_auraParts[player] = nil
end

function CombatService:KnitStart()
	GameService = Knit.GetService("GameService")
	EnemyService = Knit.GetService("EnemyService")

	RunService.Heartbeat:Connect(function(dt: number)
		self:_updateOrbiters(dt)
		self:_updateProjectiles(dt)
		self:_updateLightning(dt)
		self:_updateAura(dt)
	end)
end

return CombatService
