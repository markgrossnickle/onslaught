--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local CharacterData = require(ReplicatedStorage.Shared.CharacterData)

export type GameState = "WaitingForPlayers" | "Lobby" | "Intermission" | "Wave" | "GameOver" | "Victory"

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
		RespawnCountdown = Knit.CreateSignal(), -- (secondsLeft: number)
		FirstRunTutorial = Knit.CreateSignal(), -- () fired to first-time players
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
	Victory: boolean,
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
	XPMultiplier: number, -- from relics + character
	XP: number,
	Level: number,
	Upgrades: { [string]: number }, -- upgradeId -> stack count
	Kills: number,
	DeathCount: number,
	LastDamageTime: number,
	PendingLevelUps: number, -- queued level-ups waiting for card picks
	LastStandUsed: boolean, -- Last Stand relic: survive one killing blow
	Character: string, -- selected character id
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
local StatsService: any
local PowerUpService: any

-- Timed run
local RUN_DURATION = 900 -- 15 minutes
local MEGA_BOSS_TIME = 840 -- 14 minutes
local ENRAGE_TIME = RUN_DURATION -- 15 minutes
local _megaBossSpawned: boolean = false
local _lobbyReadyPlayers: { [Player]: boolean } = {}
local _lobbyTimeout: number = 30
local _hasMobilePlayer: boolean = false
local _firstGame: boolean = true

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

function GameService:GetPlayerCount(): number
	local count = 0
	for p in _playerStats do
		if p.Parent == Players then
			count += 1
		end
	end
	return math.max(1, count)
end

function GameService:_startNextWave()
	_currentWave += 1
	local cfg = GameConfig.Waves
	local baseCount = cfg.BaseEnemyCount + ((_currentWave - 1) * cfg.EnemiesPerWave)

	-- Scale enemy count by player count
	local playerCount = self:GetPlayerCount()
	local countMult = 1.0 + GameConfig.Scaling.EnemyCountPerPlayer * (playerCount - 1)
	local enemyCount = math.floor(baseCount * countMult)
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

function GameService:GetAllPlayerStats(): { [Player]: PlayerStats }
	return _playerStats
end

function GameService:_initPlayerStats(player: Player): PlayerStats
	local cfg = GameConfig.Player

	-- Base stats
	local maxHealth = cfg.MaxHealth
	local walkSpeed = cfg.BaseWalkSpeed
	local damageMult = 1.0
	local healthRegen = 0
	local magnetRange = cfg.BaseMagnetRange
	local xpMult = 1.0
	local lastStandAvailable = false
	local characterId = "Survivor"

	-- Apply relic bonuses (from persistent data)
	if StatsService then
		local relicLevels = StatsService:GetRelicLevels(player)
		local toughSkin = relicLevels["ToughSkin"] or 0
		maxHealth += toughSkin * 10

		local swiftFeet = relicLevels["SwiftFeet"] or 0
		walkSpeed = math.floor(walkSpeed * (1 + swiftFeet * 0.05))

		local keenEdge = relicLevels["KeenEdge"] or 0
		damageMult += keenEdge * 0.08

		local magPull = relicLevels["MagneticPull"] or 0
		magnetRange *= (1 + magPull * 0.15)

		local quickLearner = relicLevels["QuickLearner"] or 0
		xpMult += quickLearner * 0.10

		local regen = relicLevels["Regeneration"] or 0
		healthRegen += regen * 1

		local lastStand = relicLevels["LastStand"] or 0
		lastStandAvailable = lastStand > 0

		characterId = StatsService:GetSelectedCharacter(player)
	end

	-- Apply character passive bonuses
	local charDef = CharacterData.GetCharacter(characterId)
	if charDef and charDef.Passive then
		if charDef.Passive.MaxHealthMult then
			maxHealth = math.floor(maxHealth * charDef.Passive.MaxHealthMult)
		end
		if charDef.Passive.DamageMult then
			damageMult *= charDef.Passive.DamageMult
		end
		if charDef.Passive.SpeedMult then
			walkSpeed = math.floor(walkSpeed * charDef.Passive.SpeedMult)
		end
		if charDef.Passive.XPMult then
			xpMult *= charDef.Passive.XPMult
		end
	end

	local stats: PlayerStats = {
		MaxHealth = maxHealth,
		Health = maxHealth,
		DamageMultiplier = damageMult,
		WalkSpeed = walkSpeed,
		HealthRegen = healthRegen,
		MagnetRange = magnetRange,
		XPMultiplier = xpMult,
		XP = 0,
		Level = 1,
		Upgrades = {},
		Kills = 0,
		DeathCount = 0,
		LastDamageTime = 0,
		PendingLevelUps = 0,
		LastStandUsed = not lastStandAvailable, -- if no relic, mark as "used"
		Character = characterId,
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

	-- Void Shield: blocks one hit completely
	if PowerUpService and PowerUpService:HasShield(player) then
		PowerUpService:ConsumeShield(player)
		return
	end

	stats.Health = math.max(0, stats.Health - damage)

	-- Last Stand relic: survive one killing blow per run
	if stats.Health <= 0 and not stats.LastStandUsed then
		stats.LastStandUsed = true
		stats.Health = 1
	end

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
	local stats = _playerStats[player]
	if stats then
		-- Clear pending level-ups so stale card picks can't apply after death
		stats.PendingLevelUps = 0
		stats.DeathCount += 1
	end

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
		self:_endRun(false)
	else
		local cfg = GameConfig.Player
		local deathCount = stats and stats.DeathCount or 1
		local respawnDelay = math.min(cfg.BaseRespawnDelay + deathCount * cfg.RespawnDelayPerDeath, cfg.MaxRespawnDelay)

		-- Send respawn countdown to the dead player
		task.spawn(function()
			for i = respawnDelay, 1, -1 do
				if player.Parent ~= Players then
					return
				end
				self.Client.RespawnCountdown:Fire(player, i)
				task.wait(1)
			end
		end)

		task.delay(respawnDelay, function()
			if player.Parent == Players then
				local respawnStats = _playerStats[player]
				if respawnStats then
					-- Level loss on respawn: lose 1 level (min 1), remove a stat upgrade
					self:_applyRespawnPenalty(respawnStats, player)
					respawnStats.Health = respawnStats.MaxHealth
					self:_syncStats(player)
					self:_respawnPlayer(player)
				end
			end
		end)
	end
end

function GameService:_applyRespawnPenalty(stats: PlayerStats, player: Player)
	if stats.Level <= 1 then
		return
	end

	stats.Level -= 1

	-- Remove one stat upgrade stack (prioritize most-stacked stat)
	local statUpgrades = { "DamageUp", "SpeedUp", "RegenUp", "MagnetUp", "MaxHealthUp" }
	local bestId: string? = nil
	local bestStacks = 0
	for _, id in statUpgrades do
		local stacks = stats.Upgrades[id] or 0
		if stacks > bestStacks then
			bestStacks = stacks
			bestId = id
		end
	end

	if bestId and bestStacks > 0 then
		stats.Upgrades[bestId] = bestStacks - 1
		-- Reverse the stat effect
		if bestId == "DamageUp" then
			stats.DamageMultiplier = math.max(1.0, stats.DamageMultiplier - 0.25)
			CombatService:UpdateDamage(player)
		elseif bestId == "SpeedUp" then
			stats.WalkSpeed = math.max(GameConfig.Player.BaseWalkSpeed, math.floor(stats.WalkSpeed / 1.2))
		elseif bestId == "RegenUp" then
			stats.HealthRegen = math.max(0, stats.HealthRegen - 2)
		elseif bestId == "MagnetUp" then
			stats.MagnetRange = math.max(GameConfig.Player.BaseMagnetRange, stats.MagnetRange / 1.5)
		elseif bestId == "MaxHealthUp" then
			stats.MaxHealth = math.max(GameConfig.Player.MaxHealth, stats.MaxHealth - 25)
		end
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

function GameService:HasMobilePlayer(): boolean
	return _hasMobilePlayer
end

function GameService:GetMaxConcurrentEnemies(): number
	if _hasMobilePlayer then
		return GameConfig.Mobile.MaxConcurrentEnemies
	end
	return GameConfig.Enemies.MaxConcurrent
end

function GameService:SpawnXPGem(position: Vector3, value: number)
	local cfg = GameConfig.XPGems

	-- Cap gems to prevent performance issues; use mobile cap if any mobile player
	local maxGems = cfg.MaxGems
	if _hasMobilePlayer then
		maxGems = GameConfig.Mobile.MaxGems
	end
	if #_xpGems >= maxGems then
		local oldest = _xpGems[1]
		if oldest.Part and oldest.Part.Parent then
			oldest.Part:Destroy()
		end
		table.remove(_xpGems, 1)
	end

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

function GameService:MagnetBurstAllGems(player: Player)
	local char = player.Character
	if not char then
		return
	end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	-- Instantly teleport all gems to the player position (they'll be collected next frame)
	for _, gem in _xpGems do
		if gem.Part and gem.Part.Parent then
			gem.Part.Position = root.Position
		end
	end
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

	stats.XP += math.floor(amount * stats.XPMultiplier)
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
		-- Check weapon unlocks (persistent progression)
		local unlockedWeapons = StatsService and StatsService:GetUnlockedWeapons(player) or { Orbiter = true }

		-- Don't offer weapon unlock cards if already owned or not unlocked
		if card.Id == "NewProjectile" then
			if not unlockedWeapons["Projectile"] then
				continue
			end
			local ws = CombatService:GetWeaponState(player)
			if ws and ws.HasProjectile then
				continue
			end
		end
		if card.Id == "NewLightning" then
			if not unlockedWeapons["Lightning"] then
				continue
			end
			local ws = CombatService:GetWeaponState(player)
			if ws and ws.HasLightning then
				continue
			end
		end
		if card.Id == "NewAura" then
			if not unlockedWeapons["Aura"] then
				continue
			end
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
-- END RUN / VICTORY
-------------------------------------------------

function GameService:_endRun(victory: boolean)
	local endState: GameState = if victory then "Victory" else "GameOver"
	self:_setState(endState)

	for p, pStats in _playerStats do
		if p.Parent == Players then
			local data: GameOverData = {
				SurvivalTime = _gameElapsed,
				Kills = pStats.Kills,
				Level = pStats.Level,
				Wave = _currentWave,
				Victory = victory,
			}
			self.Client.GameOverData:Fire(p, data)
		end
	end

	_running = false
	_megaBossSpawned = false

	-- Transition to lobby after a short delay
	task.delay(3, function()
		if _state == endState then
			self:_enterLobby()
		end
	end)
end

function GameService:MegaBossKilled()
	if _megaBossSpawned then
		self:_endRun(true)
	end
end

function GameService:_checkTimedRun()
	if not _running then
		return
	end

	-- Spawn mega-boss at 14 minutes
	if _gameElapsed >= MEGA_BOSS_TIME and not _megaBossSpawned then
		_megaBossSpawned = true
		-- The actual mega-boss spawn is handled by EnemyService listening for this
		self.GameStateChanged:Fire("MegaBoss")
	end

	-- Enrage at 15 minutes (handled by EnemyService)
	if _gameElapsed >= ENRAGE_TIME and _megaBossSpawned then
		self.GameStateChanged:Fire("Enrage")
	end
end

-------------------------------------------------
-- LOBBY
-------------------------------------------------

function GameService:_enterLobby()
	self:_setState("Lobby")
	table.clear(_lobbyReadyPlayers)

	-- Start lobby timeout
	task.spawn(function()
		local waited = 0
		while _state == "Lobby" and waited < _lobbyTimeout do
			task.wait(1)
			waited += 1
		end
		if _state == "Lobby" then
			self:_startNewRun()
		end
	end)
end

function GameService:_startNewRun()
	-- Re-init all players with fresh stats (relic bonuses re-applied)
	self:_clearAllGems()
	for p in _playerStats do
		if p.Parent == Players then
			self:_initPlayerStats(p)
			CombatService:ResetPlayer(p)

			-- Apply character starting weapon bonuses
			local charDef = CharacterData.GetCharacter(self:GetPlayerStats(p).Character)
			if charDef then
				-- Berserker gets extra orbiters
				if charDef.Passive.ExtraOrbiters then
					local ws = CombatService:GetWeaponState(p)
					if ws then
						ws.OrbiterCount += charDef.Passive.ExtraOrbiters
						CombatService:_rebuildOrbiters(p)
					end
				end
				-- Guardian starts with Aura if unlocked
				if charDef.StartingWeapon == "Aura" and charDef.Id == "Guardian" then
					local unlockedWeapons = StatsService and StatsService:GetUnlockedWeapons(p) or { Orbiter = true }
					if unlockedWeapons["Aura"] then
						CombatService:ApplyWeaponUpgrade(p, "NewAura")
					end
				end
			end

			self:_syncStats(p)
			self:_respawnPlayer(p)
		end
	end

	_megaBossSpawned = false
	self:StartGame()
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

function GameService.Client:ReadyUp(player: Player): boolean
	if _state ~= "Lobby" then
		return false
	end
	_lobbyReadyPlayers[player] = true

	-- Check if all players are ready
	local allReady = true
	for p in _playerStats do
		if p.Parent == Players and not _lobbyReadyPlayers[p] then
			allReady = false
			break
		end
	end

	if allReady then
		self.Server:_startNewRun()
	end
	return true
end

function GameService.Client:PlayAgain(_player: Player): boolean
	if _state ~= "GameOver" and _state ~= "Victory" and _running then
		return false
	end
	-- Trigger lobby transition
	if _state ~= "Lobby" then
		self.Server:_enterLobby()
	end
	return true
end

function GameService.Client:ReportPlatform(_player: Player, platform: string): boolean
	if platform == "Mobile" then
		_hasMobilePlayer = true
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
		_lobbyReadyPlayers[player] = nil
	end)
end

function GameService:KnitStart()
	Players.CharacterAutoLoads = false
	CombatService = Knit.GetService("CombatService")
	StatsService = Knit.GetService("StatsService")
	PowerUpService = Knit.GetService("PowerUpService")

	-- Spawn late joiners
	Players.PlayerAdded:Connect(function(player: Player)
		task.wait(2)
		if player.Parent == Players then
			self:_respawnPlayer(player)
			self:_syncStats(player)
		end
	end)

	-- Wait for first player, then enter lobby (allows character select before first run)
	task.spawn(function()
		if #Players:GetPlayers() == 0 then
			Players.PlayerAdded:Wait()
		end
		task.wait(2)

		for _, player in Players:GetPlayers() do
			self:_respawnPlayer(player)
		end

		task.wait(1)
		_firstGame = true
		self:_enterLobby()

		-- Send first-run tutorial to new players
		task.defer(function()
			for _, player in Players:GetPlayers() do
				if StatsService then
					local lifetimeStats = StatsService:GetLifetimeStats(player)
					if lifetimeStats and lifetimeStats.TotalRuns == 0 then
						self.Client.FirstRunTutorial:Fire(player)
					end
				end
			end
		end)
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
			self:_checkTimedRun()
		end
	end)
end

return GameService
