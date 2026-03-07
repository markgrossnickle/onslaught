--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Promise = require(ReplicatedStorage.Packages.Promise)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

export type GameState = "WaitingForPlayers" | "Intermission" | "Wave" | "GameOver"

local GameService = Knit.CreateService({
	Name = "GameService",
	Client = {
		GameStateChanged = Knit.CreateSignal(),
		WaveChanged = Knit.CreateSignal(),
		IntermissionTick = Knit.CreateSignal(),
		PlayerStatsChanged = Knit.CreateSignal(),
	},

	-- Signals
	WaveStarted = Signal.new(),
	WaveEnded = Signal.new(),
	GameStateChanged = Signal.new(),
})

-- State
local _state: GameState = "WaitingForPlayers"
local _currentWave: number = 0
local _enemiesRemaining: number = 0
local _running: boolean = false

-- Player stats (runtime, not persisted)
export type PlayerStats = {
	MaxHealth: number,
	Health: number,
	DamageMultiplier: number,
	WalkSpeed: number,
	HealthRegen: number,
	XP: number,
	Level: number,
	UpgradePoints: number,
	Upgrades: { [string]: number },
	Kills: number,
}

local _playerStats: { [Player]: PlayerStats } = {}

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

	-- Grant upgrade points
	for player, stats in _playerStats do
		if player.Parent == Players then
			stats.UpgradePoints += 1
			self:_syncStats(player)
		end
	end

	-- Intermission countdown
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

	-- Heal all players
	for player, stats in _playerStats do
		if player.Parent == Players then
			stats.Health = stats.MaxHealth
			self:_syncStats(player)
			self:_respawnPlayer(player)
		end
	end

	self:_startNextWave()
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
		XP = 0,
		Level = 1,
		UpgradePoints = 0,
		Upgrades = {},
		Kills = 0,
	}
	_playerStats[player] = stats
	return stats
end

function GameService:_syncStats(player: Player)
	local stats = _playerStats[player]
	if stats and player.Parent == Players then
		self.Client.PlayerStatsChanged:Fire(player, stats)

		-- Apply walkspeed to character
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

	stats.Health = math.max(0, stats.Health - damage)
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

	-- Check if all players are dead
	local allDead = true
	for p, s in _playerStats do
		if p.Parent == Players and s.Health > 0 then
			allDead = false
			break
		end
	end

	if allDead then
		self:_setState("GameOver")
		task.wait(3)
		-- Reset and restart
		_running = false
		_currentWave = 0
		for p, s in _playerStats do
			if p.Parent == Players then
				self:_initPlayerStats(p)
				self:_syncStats(p)
				self:_respawnPlayer(p)
			end
		end
		self:_setState("WaitingForPlayers")
		task.wait(2)
		self:StartGame()
	else
		-- Respawn after delay
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
		stats.UpgradePoints += 1
		xpNeeded = cfg.BaseXPToLevel * (cfg.XPScaling ^ (stats.Level - 1))
	end

	self:_syncStats(player)
end

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

-- Client methods
function GameService.Client:GetState(_player: Player): (GameState, number)
	return _state, _currentWave
end

function GameService.Client:GetPlayerStats(player: Player): PlayerStats?
	return _playerStats[player]
end

function GameService.Client:RequestUpgrade(player: Player, upgradeId: string): boolean
	return self.Server:_applyUpgrade(player, upgradeId)
end

function GameService:_applyUpgrade(player: Player, upgradeId: string): boolean
	local stats = _playerStats[player]
	if not stats then
		return false
	end

	local upgradeCfg = (GameConfig.Upgrades :: any)[upgradeId]
	if not upgradeCfg then
		return false
	end

	local currentStacks = stats.Upgrades[upgradeId] or 0
	if currentStacks >= upgradeCfg.MaxStacks then
		return false
	end

	local cost = math.floor(upgradeCfg.BaseCost * (upgradeCfg.CostScaling ^ currentStacks))
	if stats.UpgradePoints < cost then
		-- Use XP as currency fallback
		if stats.XP < cost then
			return false
		end
		stats.XP -= cost
	else
		stats.UpgradePoints -= 1
	end

	stats.Upgrades[upgradeId] = currentStacks + 1

	-- Apply effect
	local effect = upgradeCfg.Effect
	if effect.Stat == "MaxHealth" then
		stats.MaxHealth += effect.Value
		stats.Health += effect.Value -- Also heal by the amount
	elseif effect.Stat == "DamageMultiplier" then
		stats.DamageMultiplier += effect.Value
	elseif effect.Stat == "WalkSpeed" then
		stats.WalkSpeed += effect.Value
	elseif effect.Stat == "HealthRegen" then
		stats.HealthRegen += effect.Value
	end

	self:_syncStats(player)
	return true
end

function GameService:KnitInit()
	Players.PlayerAdded:Connect(function(player: Player)
		self:_initPlayerStats(player)

		player.CharacterAdded:Connect(function(character)
			-- Disable default respawn
			local humanoid = character:WaitForChild("Humanoid") :: Humanoid
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
	-- Disable auto respawn
	Players.CharacterAutoLoads = false

	-- Wait for first player, then start
	task.spawn(function()
		if #Players:GetPlayers() == 0 then
			Players.PlayerAdded:Wait()
		end
		-- Give the player time to load
		task.wait(2)

		-- Spawn all current players
		for _, player in Players:GetPlayers() do
			self:_respawnPlayer(player)
		end

		task.wait(2)
		self:StartGame()
	end)

	-- Health regen loop
	task.spawn(function()
		self:_regenLoop()
	end)
end

return GameService
