--!strict
local Players = game:GetService("Players")
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
}

local EnemyService = Knit.CreateService({
	Name = "EnemyService",
	Client = {
		EnemyDamaged = Knit.CreateSignal(),
		EnemyKilled = Knit.CreateSignal(),
	},

	EnemyKilled = Signal.new(), -- (enemyData, killerPlayer)
})

local _enemies: { EnemyData } = {}
local _enemyFolder: Folder = nil :: any
local _spawning: boolean = false
local _lastBossSpawnTime: number = 0

local GameService: any
local ArenaService: any

function EnemyService:_createEnemyModel(enemyType: string, position: Vector3): Model
	local cfg = (GameConfig.Enemies.Types :: any)[enemyType]
	if not cfg then
		error("Unknown enemy type: " .. enemyType)
	end

	local model = Instance.new("Model")
	model.Name = enemyType

	-- Body
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = cfg.Size
	body.Color = cfg.Color
	body.Material = Enum.Material.SmoothPlastic
	body.Position = position
	body.Anchored = false
	body.CanCollide = true
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Parent = model

	-- Eye (so enemies have a "face")
	local eye1 = Instance.new("Part")
	eye1.Name = "Eye1"
	eye1.Size = Vector3.new(0.6, 0.6, 0.3)
	eye1.Color = Color3.fromRGB(255, 255, 0)
	eye1.Material = Enum.Material.Neon
	eye1.Anchored = false
	eye1.CanCollide = false

	local weld1 = Instance.new("WeldConstraint")
	weld1.Part0 = body
	weld1.Part1 = eye1
	weld1.Parent = eye1

	eye1.CFrame = body.CFrame * CFrame.new(-0.8, cfg.Size.Y * 0.2, -cfg.Size.Z / 2 - 0.1)
	eye1.Parent = model

	local eye2 = eye1:Clone()
	eye2.Name = "Eye2"
	eye2.CFrame = body.CFrame * CFrame.new(0.8, cfg.Size.Y * 0.2, -cfg.Size.Z / 2 - 0.1)
	local weld2 = eye2:FindFirstChildOfClass("WeldConstraint")
	if weld2 then
		weld2.Part0 = body
		weld2.Part1 = eye2
	end
	eye2.Parent = model

	-- Health bar billboard
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HealthBar"
	billboard.Size = UDim2.new(0, 60, 0, 8)
	billboard.StudsOffset = Vector3.new(0, cfg.Size.Y / 2 + 1.5, 0)
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

	-- BodyMovers for AI movement
	local attachment = Instance.new("Attachment")
	attachment.Name = "MoveAttachment"
	attachment.Parent = body

	local alignPosition = Instance.new("AlignPosition")
	alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
	alignPosition.Attachment0 = attachment
	alignPosition.MaxForce = 50000
	alignPosition.MaxVelocity = cfg.Speed
	alignPosition.Responsiveness = 15
	alignPosition.Position = position
	alignPosition.Parent = body

	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = attachment
	alignOrientation.MaxTorque = 50000
	alignOrientation.Responsiveness = 20
	alignOrientation.Parent = body

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

	enemy.Health -= damage

	-- Notify clients for VFX
	local pos = Vector3.zero
	if enemy.Model.PrimaryPart then
		pos = enemy.Model.PrimaryPart.Position
	end
	self.Client.EnemyDamaged:FireAll(enemy.Model, damage, pos)

	-- Update health bar
	self:_updateHealthBar(enemy)

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

	GameService:EnemyKilled(killer)

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

function EnemyService:_updateEnemies(dt: number)
	local now = tick()

	for _, enemy in _enemies do
		if not enemy.Alive then
			continue
		end
		if not enemy.Model or not enemy.Model.Parent or not enemy.Model.PrimaryPart then
			continue
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

		-- Attack
		if dist <= enemy.AttackRange and (now - enemy.LastAttackTime) >= enemy.AttackCooldown then
			enemy.LastAttackTime = now
			GameService:DamagePlayer(target, enemy.Damage)
		end
	end
end

function EnemyService:_getAvailableTypes(wave: number, gameElapsed: number): { string }
	local waveCfg = GameConfig.Waves
	local enemyCfg = GameConfig.Enemies

	local types = { "Grunt" }
	if wave >= waveCfg.BruteIntroWave then
		table.insert(types, "Brute")
	end
	if wave >= waveCfg.DasherIntroWave then
		table.insert(types, "Dasher")
	end

	-- Time-based introductions
	for typeName, introTime in enemyCfg.IntroTimes do
		if gameElapsed >= introTime and not table.find(types, typeName) then
			table.insert(types, typeName)
		end
	end

	return types
end

function EnemyService:_spawnWaveEnemies(wave: number, totalEnemies: number)
	_spawning = true
	local waveCfg = GameConfig.Waves
	local maxConcurrent = GameConfig.Enemies.MaxConcurrent

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
		local positions = ArenaService:GetSpawnPositions(1)
		self:SpawnEnemy(enemyType, positions[1])
		spawned += 1

		if spawned < totalEnemies then
			task.wait(spawnInterval)
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

	if #_enemies >= enemyCfg.MaxConcurrent then
		return
	end

	local timeSinceLastBoss = gameElapsed - _lastBossSpawnTime
	if _lastBossSpawnTime == 0 then
		-- First boss
		if gameElapsed >= enemyCfg.BossStartTime then
			_lastBossSpawnTime = gameElapsed
			local positions = ArenaService:GetSpawnPositions(1)
			self:SpawnEnemy("Boss", positions[1])
		end
	elseif timeSinceLastBoss >= enemyCfg.BossInterval then
		_lastBossSpawnTime = gameElapsed
		local positions = ArenaService:GetSpawnPositions(1)
		self:SpawnEnemy("Boss", positions[1])
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

	-- Listen for wave starts
	GameService.WaveStarted:Connect(function(wave: number, enemyCount: number)
		task.spawn(function()
			self:_spawnWaveEnemies(wave, enemyCount)
		end)
	end)

	-- Clear enemies on game over
	GameService.GameStateChanged:Connect(function(state: string)
		if state == "GameOver" or state == "WaitingForPlayers" then
			self:_clearAllEnemies()
			_lastBossSpawnTime = 0
		end
	end)

	-- AI update loop + boss spawn check
	game:GetService("RunService").Heartbeat:Connect(function(dt: number)
		self:_updateEnemies(dt)
		self:_checkBossSpawn()
	end)
end

return EnemyService
