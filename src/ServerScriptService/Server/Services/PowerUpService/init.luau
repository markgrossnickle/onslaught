--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

export type PowerUpOrb = {
	Part: BasePart,
	Type: string,
	SpawnTime: number,
}

export type VoidChest = {
	Model: Model,
	Position: Vector3,
	Active: boolean,
}

export type ActiveBuff = {
	Type: string,
	ExpiresAt: number,
	Player: Player,
}

local PowerUpService = Knit.CreateService({
	Name = "PowerUpService",
	Client = {
		PowerUpCollected = Knit.CreateSignal(), -- (powerUpType, name)
		BuffStarted = Knit.CreateSignal(), -- (powerUpType, duration)
		BuffEnded = Knit.CreateSignal(), -- (powerUpType)
		ChestSpawned = Knit.CreateSignal(), -- (position)
		ChestCollected = Knit.CreateSignal(), -- (position)
		VoidBombExploded = Knit.CreateSignal(), -- (position)
	},
})

local _orbs: { PowerUpOrb } = {}
local _orbFolder: Folder = nil :: any
local _activeBuffs: { ActiveBuff } = {}
local _chest: VoidChest? = nil
local _chestModel: Model? = nil
local _lastChestTime: number = 0
local _shieldPlayers: { [Player]: boolean } = {}
local _doubleXPPlayers: { [Player]: boolean } = {}
local _speedBoostPlayers: { [Player]: number } = {} -- original walk speed

local GameService: any
local EnemyService: any

-------------------------------------------------
-- ORB CREATION
-------------------------------------------------

local function createPowerUpOrb(powerUpType: string, position: Vector3, parent: Instance): BasePart
	local puCfg = (GameConfig.PowerUps.Types :: any)[powerUpType]
	local orbSize = GameConfig.PowerUps.OrbSize

	local orb = Instance.new("Part")
	orb.Name = "PowerUp_" .. powerUpType
	orb.Shape = Enum.PartType.Ball
	orb.Size = orbSize
	orb.Color = puCfg.Color
	orb.Material = Enum.Material.Neon
	orb.Anchored = true
	orb.CanCollide = false
	orb.CastShadow = false
	orb.Transparency = 0.1
	orb.Position = position + Vector3.new(0, 2, 0)
	orb.Parent = parent

	-- Inner glow
	local glow = Instance.new("Part")
	glow.Name = "Glow"
	glow.Shape = Enum.PartType.Ball
	glow.Size = orbSize * 0.5
	glow.Color = puCfg.Color
	glow.Material = Enum.Material.Neon
	glow.Anchored = true
	glow.CanCollide = false
	glow.CastShadow = false
	glow.Transparency = 0
	glow.Position = orb.Position
	glow.Parent = parent

	-- Particle trail
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Trail"
	emitter.Color = ColorSequence.new(puCfg.Color)
	emitter.Size = NumberSequence.new(0.3, 0)
	emitter.Lifetime = NumberRange.new(0.3, 0.6)
	emitter.Rate = 10
	emitter.Speed = NumberRange.new(0.5, 1.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission = 1
	emitter.Parent = orb

	-- Store type as attribute
	orb:SetAttribute("PowerUpType", powerUpType)
	orb:SetAttribute("GlowId", glow.Name .. tostring(math.random(10000)))

	return orb
end

-------------------------------------------------
-- CHEST CREATION
-------------------------------------------------

local function createVoidChest(position: Vector3, parent: Instance): Model
	local cfg = GameConfig.PowerUps
	local model = Instance.new("Model")
	model.Name = "VoidChest"

	-- Chest body
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(3, 2.5, 2.5)
	body.Color = cfg.ChestColor
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.CastShadow = false
	body.Position = position + Vector3.new(0, 2, 0)
	body.Parent = model

	-- Lid
	local lid = Instance.new("Part")
	lid.Name = "Lid"
	lid.Size = Vector3.new(3.2, 0.5, 2.7)
	lid.Color = cfg.ChestColor
	lid.Material = Enum.Material.SmoothPlastic
	lid.Anchored = true
	lid.CanCollide = false
	lid.CastShadow = false
	lid.Position = body.Position + Vector3.new(0, 1.5, 0)
	lid.Parent = model

	-- Glowing magenta edges (4 edge lines)
	local edgePositions = {
		{ Vector3.new(1.5, 0, 0), Vector3.new(0.15, 2.5, 2.5) },
		{ Vector3.new(-1.5, 0, 0), Vector3.new(0.15, 2.5, 2.5) },
		{ Vector3.new(0, 1.25, 1.25), Vector3.new(3, 0.15, 0.15) },
		{ Vector3.new(0, 1.25, -1.25), Vector3.new(3, 0.15, 0.15) },
	}

	for i, ep in edgePositions do
		local edge = Instance.new("Part")
		edge.Name = "Edge" .. i
		edge.Size = ep[2]
		edge.Color = cfg.ChestCoreColor
		edge.Material = Enum.Material.Neon
		edge.Anchored = true
		edge.CanCollide = false
		edge.CastShadow = false
		edge.Position = body.Position + ep[1]
		edge.Parent = model
	end

	-- Beacon: tall thin Neon Part
	local beacon = Instance.new("Part")
	beacon.Name = "Beacon"
	beacon.Size = Vector3.new(0.3, 40, 0.3)
	beacon.Color = cfg.ChestCoreColor
	beacon.Material = Enum.Material.Neon
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CastShadow = false
	beacon.Transparency = 0.3
	beacon.Position = body.Position + Vector3.new(0, 20, 0)
	beacon.Parent = model

	model.PrimaryPart = body
	model.Parent = parent

	return model
end

-------------------------------------------------
-- DROP LOGIC
-------------------------------------------------

function PowerUpService:TryDropPowerUp(enemyType: string, position: Vector3)
	if #_orbs >= GameConfig.PowerUps.MaxPowerUps then
		return
	end

	local dropChances = GameConfig.PowerUps.DropChances
	local chance = dropChances[enemyType] or dropChances.Default
	if math.random() > chance then
		return
	end

	-- Pick random power-up type
	local typeList = GameConfig.PowerUps.TypeList
	local puType = typeList[math.random(1, #typeList)]

	local orb = createPowerUpOrb(puType, position, _orbFolder)
	table.insert(_orbs, {
		Part = orb,
		Type = puType,
		SpawnTime = tick(),
	})
end

-------------------------------------------------
-- PICKUP LOGIC
-------------------------------------------------

function PowerUpService:_checkPickups()
	local now = tick()
	local toRemove: { number } = {}

	for i, orb in _orbs do
		if not orb.Part or not orb.Part.Parent then
			table.insert(toRemove, i)
			continue
		end

		-- Despawn after lifetime
		if now - orb.SpawnTime >= GameConfig.PowerUps.Lifetime then
			table.insert(toRemove, i)
			continue
		end

		-- Bob and rotate
		local age = now - orb.SpawnTime
		local bobY = math.sin(age * 3) * GameConfig.PowerUps.BobAmplitude
		local basePos = orb.Part:GetAttribute("BasePos")
		if not basePos then
			orb.Part:SetAttribute("BasePos", orb.Part.Position)
			basePos = orb.Part.Position
		end
		orb.Part.Position = basePos + Vector3.new(0, bobY, 0)
		orb.Part.CFrame = CFrame.new(orb.Part.Position) * CFrame.Angles(0, age * GameConfig.PowerUps.RotateSpeed, 0)

		-- Update glow position
		local glow = orb.Part.Parent and orb.Part.Parent:FindFirstChild("Glow") :: BasePart?
		if not glow then
			-- Glow is sibling in the folder
			for _, child in _orbFolder:GetChildren() do
				if child.Name == "Glow" and (child.Position - orb.Part.Position).Magnitude < 3 then
					glow = child :: BasePart
					break
				end
			end
		end

		-- Check player proximity (NOT magnet-pulled, walk over only)
		local collected = false
		for player, stats in pairs(GameService:GetAllPlayerStats()) do
			if stats.Health <= 0 then
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

			if (root.Position - orb.Part.Position).Magnitude < 4 then
				self:_collectPowerUp(player, orb.Type)
				collected = true
				break
			end
		end

		if collected then
			table.insert(toRemove, i)
		end
	end

	-- Remove collected/expired orbs
	for r = #toRemove, 1, -1 do
		local idx = toRemove[r]
		local orb = _orbs[idx]
		if orb.Part and orb.Part.Parent then
			-- Also remove associated glow
			local orbPos = orb.Part.Position
			orb.Part:Destroy()
			for _, child in _orbFolder:GetChildren() do
				if child.Name == "Glow" and (child.Position - orbPos).Magnitude < 5 then
					child:Destroy()
					break
				end
			end
		end
		table.remove(_orbs, idx)
	end
end

-------------------------------------------------
-- APPLY POWER-UP EFFECTS
-------------------------------------------------

function PowerUpService:_collectPowerUp(player: Player, puType: string)
	local puCfg = (GameConfig.PowerUps.Types :: any)[puType]

	self.Client.PowerUpCollected:Fire(player, puType, puCfg.Name)

	if puType == "HealthOrb" then
		GameService:HealPlayer(player, 30)
	elseif puType == "VoidShield" then
		_shieldPlayers[player] = true
		self.Client.BuffStarted:Fire(player, "VoidShield", puCfg.Duration)
		table.insert(_activeBuffs, { Type = "VoidShield", ExpiresAt = tick() + puCfg.Duration, Player = player })
	elseif puType == "MagnetBurst" then
		self:_magnetBurst(player)
	elseif puType == "SpeedSurge" then
		local stats = GameService:GetPlayerStats(player)
		if stats then
			_speedBoostPlayers[player] = stats.WalkSpeed
			stats.WalkSpeed = math.floor(stats.WalkSpeed * 1.6)
			GameService:_syncStats(player)
			self.Client.BuffStarted:Fire(player, "SpeedSurge", puCfg.Duration)
			table.insert(_activeBuffs, { Type = "SpeedSurge", ExpiresAt = tick() + puCfg.Duration, Player = player })
		end
	elseif puType == "DoubleXP" then
		_doubleXPPlayers[player] = true
		local stats = GameService:GetPlayerStats(player)
		if stats then
			stats.XPMultiplier *= 2
			GameService:_syncStats(player)
		end
		self.Client.BuffStarted:Fire(player, "DoubleXP", puCfg.Duration)
		table.insert(_activeBuffs, { Type = "DoubleXP", ExpiresAt = tick() + puCfg.Duration, Player = player })
	elseif puType == "VoidBomb" then
		self:_voidBomb(player)
	end
end

function PowerUpService:_magnetBurst(player: Player)
	-- Pull all XP gems to the player instantly
	GameService:MagnetBurstAllGems(player)
end

function PowerUpService:_voidBomb(player: Player)
	local char = player.Character
	if not char then
		return
	end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local pos = root.Position
	local radius = 30
	local damage = 100

	self.Client.VoidBombExploded:FireAll(pos)

	local enemies = EnemyService:GetEnemiesInRadius(pos, radius)
	for _, enemy in enemies do
		EnemyService:DamageEnemy(enemy, damage, player)
	end
end

-------------------------------------------------
-- BUFF EXPIRATION
-------------------------------------------------

function PowerUpService:_updateBuffs()
	local now = tick()
	local toRemove: { number } = {}

	for i, buff in _activeBuffs do
		if now >= buff.ExpiresAt then
			self:_expireBuff(buff)
			table.insert(toRemove, i)
		end
	end

	for r = #toRemove, 1, -1 do
		table.remove(_activeBuffs, toRemove[r])
	end
end

function PowerUpService:_expireBuff(buff: ActiveBuff)
	local player = buff.Player
	if player.Parent ~= Players then
		return
	end

	self.Client.BuffEnded:Fire(player, buff.Type)

	if buff.Type == "VoidShield" then
		_shieldPlayers[player] = nil
	elseif buff.Type == "SpeedSurge" then
		local originalSpeed = _speedBoostPlayers[player]
		if originalSpeed then
			local stats = GameService:GetPlayerStats(player)
			if stats then
				stats.WalkSpeed = originalSpeed
				GameService:_syncStats(player)
			end
			_speedBoostPlayers[player] = nil
		end
	elseif buff.Type == "DoubleXP" then
		if _doubleXPPlayers[player] then
			local stats = GameService:GetPlayerStats(player)
			if stats then
				stats.XPMultiplier = math.max(1, stats.XPMultiplier / 2)
				GameService:_syncStats(player)
			end
			_doubleXPPlayers[player] = nil
		end
	end
end

-------------------------------------------------
-- VOID SHIELD INTERCEPT
-------------------------------------------------

function PowerUpService:HasShield(player: Player): boolean
	return _shieldPlayers[player] == true
end

function PowerUpService:ConsumeShield(player: Player)
	if _shieldPlayers[player] then
		_shieldPlayers[player] = nil
		self.Client.BuffEnded:Fire(player, "VoidShield")
		-- Remove from active buffs
		for i, buff in _activeBuffs do
			if buff.Player == player and buff.Type == "VoidShield" then
				table.remove(_activeBuffs, i)
				break
			end
		end
	end
end

-------------------------------------------------
-- VOID CHEST
-------------------------------------------------

function PowerUpService:_updateChest()
	if not GameService or GameService:GetState() ~= "Wave" then
		return
	end

	local now = tick()
	local cfg = GameConfig.PowerUps

	-- Spawn chest periodically
	if not _chest and now - _lastChestTime >= cfg.ChestInterval then
		self:_spawnChest()
	end

	-- Check chest pickup
	if _chest and _chest.Active and _chestModel then
		for player, stats in pairs(GameService:GetAllPlayerStats()) do
			if stats.Health <= 0 then
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

			if (root.Position - _chest.Position).Magnitude < 5 then
				self:_openChest(player)
				break
			end
		end

		-- Bob the chest
		if _chestModel and _chestModel.PrimaryPart then
			local baseY = 2
			local bob = math.sin(now * 2) * 0.5
			local body = _chestModel.PrimaryPart
			body.Position = Vector3.new(_chest.Position.X, _chest.Position.Y + baseY + bob, _chest.Position.Z)
		end
	end
end

function PowerUpService:_spawnChest()
	local cfg = GameConfig.PowerUps
	local arenaCfg = GameConfig.Arena

	-- Random position within arena, away from edge
	local rng = Random.new()
	local maxDist = arenaCfg.Radius - cfg.ChestMinDistFromEdge
	local angle = rng:NextNumber(0, math.pi * 2)
	local dist = rng:NextNumber(10, maxDist)
	local pos = Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)

	_chestModel = createVoidChest(pos, _orbFolder)
	_chest = {
		Model = _chestModel,
		Position = pos,
		Active = true,
	}
	_lastChestTime = tick()

	self.Client.ChestSpawned:FireAll(pos)
end

function PowerUpService:_openChest(player: Player)
	if not _chest or not _chest.Active then
		return
	end
	_chest.Active = false

	-- Give random power-up + bonus XP
	local typeList = GameConfig.PowerUps.TypeList
	local puType = typeList[math.random(1, #typeList)]
	self:_collectPowerUp(player, puType)
	GameService:AddXP(player, GameConfig.PowerUps.ChestXPBonus)

	self.Client.ChestCollected:FireAll(_chest.Position)

	-- Destroy chest after brief delay
	if _chestModel then
		task.delay(0.5, function()
			if _chestModel and _chestModel.Parent then
				_chestModel:Destroy()
			end
			_chestModel = nil
			_chest = nil
		end)
	end
end

-------------------------------------------------
-- CLEANUP
-------------------------------------------------

function PowerUpService:ClearAll()
	for _, orb in _orbs do
		if orb.Part and orb.Part.Parent then
			orb.Part:Destroy()
		end
	end
	table.clear(_orbs)
	table.clear(_activeBuffs)
	table.clear(_shieldPlayers)
	table.clear(_doubleXPPlayers)
	table.clear(_speedBoostPlayers)

	if _chestModel and _chestModel.Parent then
		_chestModel:Destroy()
	end
	_chestModel = nil
	_chest = nil
	_lastChestTime = 0

	-- Clear stray glows
	for _, child in _orbFolder:GetChildren() do
		child:Destroy()
	end
end

-------------------------------------------------
-- LIFECYCLE
-------------------------------------------------

function PowerUpService:KnitInit()
	_orbFolder = Instance.new("Folder")
	_orbFolder.Name = "PowerUps"
	_orbFolder.Parent = workspace
end

function PowerUpService:KnitStart()
	GameService = Knit.GetService("GameService")
	EnemyService = Knit.GetService("EnemyService")

	-- Listen for enemy kills to drop power-ups
	EnemyService.EnemyKilled:Connect(function(enemyData: any, _killer: Player?)
		if enemyData.Model and enemyData.Model.PrimaryPart then
			self:TryDropPowerUp(enemyData.Type, enemyData.Model.PrimaryPart.Position)
		end
	end)

	-- Clear on game state changes
	GameService.GameStateChanged:Connect(function(state: string)
		if state == "GameOver" or state == "Victory" or state == "Lobby" or state == "WaitingForPlayers" then
			self:ClearAll()
		end
	end)

	-- Cleanup on player leaving
	Players.PlayerRemoving:Connect(function(player: Player)
		_shieldPlayers[player] = nil
		_doubleXPPlayers[player] = nil
		_speedBoostPlayers[player] = nil

		-- Remove any active buffs for this player
		for i = #_activeBuffs, 1, -1 do
			if _activeBuffs[i].Player == player then
				table.remove(_activeBuffs, i)
			end
		end
	end)

	-- Update loop
	RunService.Heartbeat:Connect(function(_dt: number)
		self:_checkPickups()
		self:_updateBuffs()
		self:_updateChest()
	end)
end

return PowerUpService
