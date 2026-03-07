--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

export type GameState = "WaitingForPlayers" | "Intermission" | "Wave" | "GameOver"

local GameService = Knit.CreateService({
	Name = "GameService",
	Client = {
		GameStateChanged = Knit.CreateSignal(),
		WaveChanged = Knit.CreateSignal(),
		IntermissionTick = Knit.CreateSignal(),
		PlayerStatsChanged = Knit.CreateSignal(),
		PlayerDamaged = Knit.CreateSignal(),
		ShowUpgradeCards = Knit.CreateSignal(), -- (cards: {{Id, Name, Description}})
		XPGemCollected = Knit.CreateSignal(), -- (amount: number)
		GameTimerTick = Knit.CreateSignal(), -- (elapsedSeconds: number)
		GameOverData = Knit.CreateSignal(), -- (data: GameOverData)
	},

	WaveStarted = Signal.new(),
	WaveEnded = Signal.new(),
	GameStateChanged = Signal.new(),
	PlayerLeveledUp = Signal.new(), -- (player)
})

-- Game over stats sent to clients
export type GameOverData = {
	SurvivalTime: number,
	Kills: number,
	Level: number,
	Wave: number,
}

-- State
local _state: GameState = "WaitingForPlayers"
local _currentWave: number = 0
local _enemiesRemaining: number = 0
local _running: boolean = false
local _gameStartTime: number = 0 -- tick() when game started
local _gameElapsed: number = 0 -- seconds of game time elapsed

-- Player stats (runtime, not persisted)
export type PlayerStats = {
	MaxHealth: number,
	Health: number,
	DamageMultiplier: number,
	WalkSpeed: number,
	HealthRegen: number,
	MagnetRange: number,
	XP: number,
	Level: number,
	Upgrades: { [string]: number }, -- upgradeId -> stack count
	Kills: number,
	LastDamageTime: number,
	PendingLevelUps: number, -- queued level-ups waiting for card picks
}

local _playerStats: { [Player]: PlayerStats } = {}

-- XP Gems in the world
export type XPGem = {
	Part: BasePart,
	Value: number,
	SpawnTime: number,
}
local _xpGems: { XPGem } = {}
local _gemFolder: Folder = nil :: any

local CombatService: any

function GameService:GetState(): GameState
	return _state
end

function GameService:GetCurrentWave(): number
	return _currentWave
end

function GameService:GetEnemiesRemaining(): number
	return _enemiesRemaining
end

function GameService:SetEnemiesRemaining(count: number)
	_enemiesRemaining = count
end

function GameService:EnemyKilled(killerPlayer: Player?)
	_enemiesRemaining = math.max(0, _enemiesRemaining - 1)
	if killerPlayer then
		local stats = _playerStats[killerPlayer]
		if stats then
			stats.Kills += 1
		end
	end
	if _enemiesRemaining <= 0 and _state == "Wave" then
		self:_endWave()
	end
end

function GameService:_setState(newState: GameState)
	_state = newState
	self.GameStateChanged:Fire(newState)
	self.Client.GameStateChanged:FireAll(newState, _currentWave)
end

function GameService:_endWave()
	self:_setState("Intermission")
	self.WaveEnded:Fire(_currentWave)

	task.spawn(function()
		for i = GameConfig.Waves.IntermissionTime, 1, -1 do
			if _state ~= "Intermission" then
				return
			end
			self.Client.IntermissionTick:FireAll(i)
			task.wait(1)
		end
		if _state == "Intermission" then
			self:_startNextWave()
		end
	end)
end

function GameService:_startNextWave()
	_currentWave += 1
	local cfg = GameConfig.Waves
	local enemyCount = cfg.BaseEnemyCount + ((_currentWave - 1) * cfg.EnemiesPerWave)
	_enemiesRemaining = enemyCount

	self:_setState("Wave")
	self.Client.WaveChanged:FireAll(_currentWave, enemyCount)
	self.WaveStarted:Fire(_currentWave, enemyCount)
end

function GameService:StartGame()
	if _running then
		return
	end
	_running = true
	_currentWave = 0
	_gameStartTime = tick()
	_gameElapsed = 0

	for player, stats in _playerStats do
		if player.Parent == Players then
			stats.Health = stats.MaxHealth
			self:_syncStats(player)
			self:_respawnPlayer(player)
		end
	end

	self:_startNextWave()
end

function GameService:GetGameElapsed(): number
	return _gameElapsed
end

function GameService:GetPlayerStats(player: Player): PlayerStats?
	return _playerStats[player]
end

function GameService:_initPlayerStats(player: Player): PlayerStats
	local cfg = GameConfig.Player
	local stats: PlayerStats = {
		MaxHealth = cfg.MaxHealth,
		Health = cfg.MaxHealth,
		DamageMultiplier = 1.0,
		WalkSpeed = cfg.BaseWalkSpeed,
		HealthRegen = 0,
		MagnetRange = cfg.BaseMagnetRange,
		XP = 0,
		Level = 1,
		Upgrades = {},
		Kills = 0,
		LastDamageTime = 0,
		PendingLevelUps = 0,
	}
	_playerStats[player] = stats
	return stats
end

function GameService:_syncStats(player: Player)
	local stats = _playerStats[player]
	if stats and player.Parent == Players then
		self.Client.PlayerStatsChanged:Fire(player, stats)

		local char = player.Character
		if char then
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = stats.WalkSpeed
			end
		end
	end
end

function GameService:DamagePlayer(player: Player, damage: number)
	local stats = _playerStats[player]
	if not stats then
		return
	end
	if stats.Health <= 0 then
		return
	end

	local now = tick()
	if (now - stats.LastDamageTime) < GameConfig.Player.InvincibilityTime then
		return
	end
	stats.LastDamageTime = now

	stats.Health = math.max(0, stats.Health - damage)
	self.Client.PlayerDamaged:Fire(player, damage)
	self:_syncStats(player)

	if stats.Health <= 0 then
		self:_onPlayerDied(player)
	end
end

function GameService:HealPlayer(player: Player, amount: number)
	local stats = _playerStats[player]
	if not stats then
		return
	end
	stats.Health = math.min(stats.MaxHealth, stats.Health + amount)
	self:_syncStats(player)
end

function GameService:_onPlayerDied(player: Player)
	local char = player.Character
	if char then
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end

	local allDead = true
	for p, s in _playerStats do
		if p.Parent == Players and s.Health > 0 then
			allDead = false
			break
		end
	end

	if allDead then
		self:_setState("GameOver")

		-- Send game over data to all players
		for p, pStats in _playerStats do
			if p.Parent == Players then
				local data: GameOverData = {
					SurvivalTime = _gameElapsed,
					Kills = pStats.Kills,
					Level = pStats.Level,
					Wave = _currentWave,
				}
				self.Client.GameOverData:Fire(p, data)
			end
		end

		_running = false
	else
		task.delay(GameConfig.Player.RespawnDelay, function()
			if player.Parent == Players then
				local stats = _playerStats[player]
				if stats then
					stats.Health = stats.MaxHealth
					self:_syncStats(player)
					self:_respawnPlayer(player)
				end
			end
		end)
	end
end

function GameService:_respawnPlayer(player: Player)
	player:LoadCharacter()
	task.defer(function()
		local char = player.Character
		if not char then
			return
		end
		local root = char:WaitForChild("HumanoidRootPart", 5) :: BasePart?
		if root then
			local spawnPos = GameConfig.Player.SpawnPosition
			root.CFrame = CFrame.new(spawnPos)
		end
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local stats = _playerStats[player]
			if stats then
				humanoid.WalkSpeed = stats.WalkSpeed
				humanoid.MaxHealth = stats.MaxHealth
				humanoid.Health = stats.Health
			end
		end
	end)
end

-------------------------------------------------
-- XP GEMS
-------------------------------------------------

function GameService:SpawnXPGem(position: Vector3, value: number)
	local cfg = GameConfig.XPGems

	local part = Instance.new("Part")
	part.Name = "XPGem"
	part.Shape = Enum.PartType.Ball
	part.Size = cfg.Size
	part.Color = cfg.Color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Position = position + Vector3.new(0, 1.5, 0)
	part.Parent = _gemFolder

	local gem: XPGem = {
		Part = part,
		Value = value,
		SpawnTime = tick(),
	}
	table.insert(_xpGems, gem)
end

function GameService:_updateXPGems(dt: number)
	local now = tick()
	local toRemove: { number } = {}

	for i, gem in _xpGems do
		if not gem.Part or not gem.Part.Parent then
			table.insert(toRemove, i)
			continue
		end

		-- Lifetime despawn
		if (now - gem.SpawnTime) >= GameConfig.XPGems.Lifetime then
			table.insert(toRemove, i)
			continue
		end

		-- Check magnet pull for each player
		local collected = false
		for player, stats in _playerStats do
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

			local dist = (root.Position - gem.Part.Position).Magnitude

			if dist < 3 then
				-- Collect
				self:_collectGem(player, gem)
				collected = true
				break
			elseif dist < stats.MagnetRange then
				-- Pull toward player
				local dir = (root.Position - gem.Part.Position).Unit
				local pullSpeed = GameConfig.XPGems.MagnetSpeed * dt
				gem.Part.Position += dir * math.min(pullSpeed, dist)
			end
		end

		if collected then
			table.insert(toRemove, i)
		end
	end

	for i = #toRemove, 1, -1 do
		local idx = toRemove[i]
		local gem = _xpGems[idx]
		if gem.Part and gem.Part.Parent then
			gem.Part:Destroy()
		end
		table.remove(_xpGems, idx)
	end
end

function GameService:_collectGem(player: Player, gem: XPGem)
	if gem.Part and gem.Part.Parent then
		gem.Part:Destroy()
	end

	self:AddXP(player, gem.Value)
	self.Client.XPGemCollected:Fire(player, gem.Value)
end

function GameService:_clearAllGems()
	for _, gem in _xpGems do
		if gem.Part and gem.Part.Parent then
			gem.Part:Destroy()
		end
	end
	table.clear(_xpGems)
end

-------------------------------------------------
-- XP / LEVELING / UPGRADE CARDS
-------------------------------------------------

function GameService:AddXP(player: Player, amount: number)
	local stats = _playerStats[player]
	if not stats then
		return
	end

	stats.XP += amount
	local cfg = GameConfig.XP
	local xpNeeded = cfg.BaseXPToLevel * (cfg.XPScaling ^ (stats.Level - 1))

	while stats.XP >= xpNeeded and stats.Level < cfg.MaxLevel do
		stats.XP -= math.floor(xpNeeded)
		stats.Level += 1
		stats.PendingLevelUps += 1
		xpNeeded = cfg.BaseXPToLevel * (cfg.XPScaling ^ (stats.Level - 1))
	end

	self:_syncStats(player)

	-- Show card selection if there are pending level-ups
	if stats.PendingLevelUps > 0 then
		self:_offerUpgradeCards(player)
	end
end

function GameService:_offerUpgradeCards(player: Player)
	local stats = _playerStats[player]
	if not stats or stats.PendingLevelUps <= 0 then
		return
	end

	local cardsCfg = GameConfig.UpgradeCards
	local available: { any } = {}

	-- Filter eligible upgrades
	for _, card in cardsCfg.Options do
		local stacks = stats.Upgrades[card.Id] or 0
		if stacks >= card.MaxStacks then
			continue
		end
		-- Check weapon requirements
		if card.RequiresWeapon then
			local ws = CombatService:GetWeaponState(player)
			if not ws then
				continue
			end
			if card.RequiresWeapon == "Projectile" and not ws.HasProjectile then
				continue
			end
			if card.RequiresWeapon == "Lightning" and not ws.HasLightning then
				continue
			end
			if card.RequiresWeapon == "Aura" and not ws.HasAura then
				continue
			end
		end
		-- Don't offer weapon unlock cards if already owned
		if card.Id == "NewProjectile" then
			local ws = CombatService:GetWeaponState(player)
			if ws and ws.HasProjectile then
				continue
			end
		end
		if card.Id == "NewLightning" then
			local ws = CombatService:GetWeaponState(player)
			if ws and ws.HasLightning then
				continue
			end
		end
		if card.Id == "NewAura" then
			local ws = CombatService:GetWeaponState(player)
			if ws and ws.HasAura then
				continue
			end
		end
		table.insert(available, card)
	end

	-- Pick random cards
	local offered: { { Id: string, Name: string, Description: string } } = {}
	local count = math.min(cardsCfg.CardsOffered, #available)

	-- Shuffle and take first N
	local shuffled = table.clone(available)
	for i = #shuffled, 2, -1 do
		local j = math.random(1, i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end

	for i = 1, count do
		local c = shuffled[i]
		table.insert(offered, { Id = c.Id, Name = c.Name, Description = c.Description })
	end

	if #offered > 0 then
		self.Client.ShowUpgradeCards:Fire(player, offered)
	else
		-- No upgrades available, just consume the level-up
		stats.PendingLevelUps -= 1
		self:_syncStats(player)
	end
end

function GameService:_applyUpgrade(player: Player, upgradeId: string): boolean
	local stats = _playerStats[player]
	if not stats or stats.PendingLevelUps <= 0 then
		return false
	end

	-- Validate the upgrade exists and is eligible
	local cardDef: any = nil
	for _, card in GameConfig.UpgradeCards.Options do
		if card.Id == upgradeId then
			cardDef = card
			break
		end
	end
	if not cardDef then
		return false
	end

	local stacks = stats.Upgrades[upgradeId] or 0
	if stacks >= cardDef.MaxStacks then
		return false
	end

	stats.Upgrades[upgradeId] = stacks + 1
	stats.PendingLevelUps -= 1

	-- Apply the effect
	if upgradeId == "DamageUp" then
		stats.DamageMultiplier += 0.25
		CombatService:UpdateDamage(player)
	elseif upgradeId == "SpeedUp" then
		stats.WalkSpeed = math.floor(stats.WalkSpeed * 1.2)
	elseif upgradeId == "RegenUp" then
		stats.HealthRegen += 2
	elseif upgradeId == "MagnetUp" then
		stats.MagnetRange *= 1.5
	elseif upgradeId == "MaxHealthUp" then
		stats.MaxHealth += 25
		stats.Health += 25
	elseif
		upgradeId == "NewProjectile"
		or upgradeId == "OrbiterCount"
		or upgradeId == "ProjectilePierce"
		or upgradeId == "ProjectileSpeed"
		or upgradeId == "NewLightning"
		or upgradeId == "LightningChain"
		or upgradeId == "NewAura"
		or upgradeId == "AuraRadius"
		or upgradeId == "AuraDamage"
	then
		CombatService:ApplyWeaponUpgrade(player, upgradeId)
		CombatService:UpdateDamage(player)
	end

	self:_syncStats(player)

	-- If more level-ups pending, offer next cards
	if stats.PendingLevelUps > 0 then
		task.defer(function()
			self:_offerUpgradeCards(player)
		end)
	end

	return true
end

-------------------------------------------------
-- REGEN
-------------------------------------------------

function GameService:_regenLoop()
	while true do
		task.wait(1)
		for player, stats in _playerStats do
			if
				player.Parent == Players
				and stats.HealthRegen > 0
				and stats.Health > 0
				and stats.Health < stats.MaxHealth
			then
				self:HealPlayer(player, stats.HealthRegen)
			end
		end
	end
end

-------------------------------------------------
-- CLIENT API
-------------------------------------------------

function GameService.Client:GetState(_player: Player): (GameState, number)
	return _state, _currentWave
end

function GameService.Client:GetPlayerStats(player: Player): PlayerStats?
	return _playerStats[player]
end

function GameService.Client:PickUpgradeCard(player: Player, upgradeId: string): boolean
	return self.Server:_applyUpgrade(player, upgradeId)
end

function GameService.Client:PlayAgain(player: Player): boolean
	if _state ~= "GameOver" and _running then
		return false
	end
	-- Reset this player and restart if not already running
	local stats = _playerStats[player]
	if stats then
		self.Server:_initPlayerStats(player)
		CombatService:ResetPlayer(player)
		self.Server:_syncStats(player)
		self.Server:_respawnPlayer(player)
	end
	if not _running then
		-- Clear gems and restart
		self.Server:_clearAllGems()
		for p, _s in _playerStats do
			if p.Parent == Players and p ~= player then
				self.Server:_initPlayerStats(p)
				CombatService:ResetPlayer(p)
				self.Server:_syncStats(p)
				self.Server:_respawnPlayer(p)
			end
		end
		self.Server:_setState("WaitingForPlayers")
		task.delay(1, function()
			self.Server:StartGame()
		end)
	end
	return true
end

-------------------------------------------------
-- LIFECYCLE
-------------------------------------------------

function GameService:KnitInit()
	_gemFolder = Instance.new("Folder")
	_gemFolder.Name = "XPGems"
	_gemFolder.Parent = workspace

	Players.PlayerAdded:Connect(function(player: Player)
		self:_initPlayerStats(player)

		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid") :: Humanoid
			humanoid.MaxHealth = math.huge
			humanoid.Health = math.huge

			humanoid.Died:Connect(function()
				-- Handled by our system
			end)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		_playerStats[player] = nil
	end)
end

function GameService:KnitStart()
	Players.CharacterAutoLoads = false
	CombatService = Knit.GetService("CombatService")

	-- Spawn late joiners
	Players.PlayerAdded:Connect(function(player: Player)
		task.wait(2)
		if player.Parent == Players then
			self:_respawnPlayer(player)
			self:_syncStats(player)
		end
	end)

	-- Wait for first player, then start
	task.spawn(function()
		if #Players:GetPlayers() == 0 then
			Players.PlayerAdded:Wait()
		end
		task.wait(2)

		for _, player in Players:GetPlayers() do
			self:_respawnPlayer(player)
		end

		task.wait(2)
		self:StartGame()
	end)

	-- Regen loop
	task.spawn(function()
		self:_regenLoop()
	end)

	-- XP gem pickup + game timer loop
	local _lastTimerTick = 0
	RunService.Heartbeat:Connect(function(dt: number)
		self:_updateXPGems(dt)

		-- Update game timer (ticks during Wave and Intermission)
		if _running and (_state == "Wave" or _state == "Intermission") then
			_gameElapsed = tick() - _gameStartTime
			local now = tick()
			if (now - _lastTimerTick) >= 1 then
				_lastTimerTick = now
				self.Client.GameTimerTick:FireAll(math.floor(_gameElapsed))
			end
		end
	end)
end

return GameService
