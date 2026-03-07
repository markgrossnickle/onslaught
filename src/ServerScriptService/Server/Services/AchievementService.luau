--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local AchievementData = require(ReplicatedStorage.Shared.AchievementData)

local AchievementService = Knit.CreateService({
	Name = "AchievementService",
	Client = {
		AchievementUnlocked = Knit.CreateSignal(), -- (achievementId: string, name: string, description: string, reward: number)
	},
})

local GameService: any
local StatsService: any
local PlayerDataService: any
local EnemyService: any

-- Track per-run state for achievement checks
local _runDamageTracker: { [Player]: { WaveStartHealth: number, TookDamage: boolean } } = {}

function AchievementService:_unlock(player: Player, achievementId: string)
	local unlocked = PlayerDataService:Read(player, { "UnlockedAchievements" }) or {}
	if unlocked[achievementId] then
		return
	end

	PlayerDataService:Write(player, { "UnlockedAchievements", achievementId }, true)

	local def = AchievementData.GetAchievement(achievementId)
	if not def then
		return
	end

	-- Award Souls reward
	if def.Reward and def.Reward > 0 then
		local souls = PlayerDataService:Read(player, { "Souls" }) or 0
		PlayerDataService:Write(player, { "Souls" }, souls + def.Reward)
	end

	-- Notify client
	self.Client.AchievementUnlocked:Fire(player, achievementId, def.Name, def.Description, def.Reward or 0)
end

function AchievementService:CheckKillMilestones(player: Player, runKills: number, lifetimeKills: number)
	if runKills >= 1 then
		self:_unlock(player, "FirstBlood")
	end
	if runKills >= 100 then
		self:_unlock(player, "Centurion")
	end
	if runKills >= 500 then
		self:_unlock(player, "Slayer")
	end
	if runKills >= 1000 then
		self:_unlock(player, "Annihilator")
	end
	if lifetimeKills >= 5000 then
		self:_unlock(player, "LifetimeHunter")
	end
end

function AchievementService:CheckWaveMilestones(player: Player, wave: number)
	if wave >= 5 then
		self:_unlock(player, "Survivor5")
	end
	if wave >= 10 then
		self:_unlock(player, "Veteran")
	end
	if wave >= 20 then
		self:_unlock(player, "Elite")
	end
	if wave >= 30 then
		self:_unlock(player, "Legend")
	end
end

function AchievementService:CheckTimeMilestones(player: Player, survivalTime: number)
	if survivalTime >= 300 then
		self:_unlock(player, "Endurance5")
	end
	if survivalTime >= 600 then
		self:_unlock(player, "Endurance10")
	end
	if survivalTime >= 1200 then
		self:_unlock(player, "Endurance20")
	end
end

function AchievementService:CheckWeaponMilestones(player: Player, weaponCount: number)
	if weaponCount >= 3 then
		self:_unlock(player, "Arsenal3")
	end
	if weaponCount >= 6 then
		self:_unlock(player, "Arsenal6")
	end
end

function AchievementService:OnEvolution(player: Player)
	self:_unlock(player, "FirstEvolution")
end

function AchievementService:OnBossKill(player: Player, bossType: string)
	self:_unlock(player, "BossSlayer")
	if bossType == "MegaBoss" then
		self:_unlock(player, "MegaBossSlayer")
	end
end

function AchievementService:OnMaxLevel(player: Player)
	self:_unlock(player, "MaxLevel")
end

function AchievementService:CheckWeaponCollection(player: Player)
	local unlocked = StatsService:GetUnlockedWeapons(player)
	-- Count all expected weapons
	local expected = {
		"Orbiter",
		"Projectile",
		"Lightning",
		"Aura",
		"VoidWhip",
		"ShadowDaggers",
		"GravityWell",
		"PlagueCloud",
		"VoidMissiles",
		"SpectralScythe",
		"SoulDrain",
		"Shockwave",
	}
	local allUnlocked = true
	for _, wId in expected do
		if not unlocked[wId] then
			allUnlocked = false
			break
		end
	end
	if allUnlocked then
		self:_unlock(player, "Collector")
	end
end

function AchievementService:OnWaveStart(player: Player)
	local stats = GameService:GetPlayerStats(player)
	if stats then
		_runDamageTracker[player] = {
			WaveStartHealth = stats.Health,
			TookDamage = false,
		}
	end
end

function AchievementService:OnPlayerDamaged(player: Player)
	local tracker = _runDamageTracker[player]
	if tracker then
		tracker.TookDamage = true
	end
end

function AchievementService:OnWaveEnd(player: Player)
	local tracker = _runDamageTracker[player]
	if tracker and not tracker.TookDamage then
		self:_unlock(player, "NoHit")
	end
end

-------------------------------------------------
-- CLIENT API
-------------------------------------------------

function AchievementService.Client:GetUnlockedAchievements(player: Player): { [string]: boolean }
	return PlayerDataService:Read(player, { "UnlockedAchievements" }) or {}
end

function AchievementService.Client:GetAllAchievements(_player: Player): { any }
	return AchievementData.Achievements
end

-------------------------------------------------
-- LIFECYCLE
-------------------------------------------------

function AchievementService:KnitInit()
	Players.PlayerRemoving:Connect(function(player: Player)
		_runDamageTracker[player] = nil
	end)
end

function AchievementService:KnitStart()
	GameService = Knit.GetService("GameService")
	StatsService = Knit.GetService("StatsService")
	PlayerDataService = Knit.GetService("PlayerDataService")
	EnemyService = Knit.GetService("EnemyService")

	-- Check kills on enemy death
	EnemyService.EnemyKilled:Connect(function(enemy: any, killer: Player?)
		if not killer then
			return
		end

		local stats = GameService:GetPlayerStats(killer)
		if not stats then
			return
		end

		local lifetimeKills = (PlayerDataService:Read(killer, { "TotalKills" }) or 0) + stats.Kills
		self:CheckKillMilestones(killer, stats.Kills, lifetimeKills)

		-- Check boss kill
		local BOSS_TYPES = {
			Boss = true,
			MegaBoss = true,
			BroodQueen = true,
			PhantomWeaver = true,
			AbyssalSerpent = true,
			VoidArchitect = true,
		}
		if BOSS_TYPES[enemy.Type] then
			self:OnBossKill(killer, enemy.Type)
		end
	end)

	-- Check wave milestones
	GameService.GameStateChanged:Connect(function(state: string)
		if state == "Wave" then
			local wave = GameService:GetCurrentWave()
			for _, player in Players:GetPlayers() do
				self:CheckWaveMilestones(player, wave)
				self:OnWaveStart(player)
			end
		elseif state == "Intermission" then
			for _, player in Players:GetPlayers() do
				self:OnWaveEnd(player)
			end
		elseif state == "GameOver" or state == "Victory" then
			local elapsed = GameService:GetGameElapsed()
			for _, player in Players:GetPlayers() do
				self:CheckTimeMilestones(player, elapsed)
				self:CheckWeaponCollection(player)
			end
		end
	end)

	-- Check weapon unlocks
	StatsService.WeaponUnlocked:Connect(function(player: Player, _weaponId: string)
		self:CheckWeaponCollection(player)
	end)
end

return AchievementService
