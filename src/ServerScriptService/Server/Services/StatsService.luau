--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local RelicData = require(ReplicatedStorage.Shared.RelicData)

local StatsService = Knit.CreateService({
	Name = "StatsService",
	Client = {
		SoulsEarned = Knit.CreateSignal(), -- (soulsEarned: number, totalSouls: number)
		WeaponUnlocked = Knit.CreateSignal(), -- (weaponName: string)
	},
	WeaponUnlocked = Signal.new(), -- (player, weaponId)
})

local GameService: any
local PlayerDataService: any

function StatsService:_setupLeaderboard(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local waveVal = Instance.new("IntValue")
	waveVal.Name = "Wave"
	waveVal.Value = 0
	waveVal.Parent = leaderstats

	local killsVal = Instance.new("IntValue")
	killsVal.Name = "Kills"
	killsVal.Value = 0
	killsVal.Parent = leaderstats

	local bestVal = Instance.new("IntValue")
	bestVal.Name = "Best"
	bestVal.Value = 0
	bestVal.Parent = leaderstats
end

function StatsService:UpdateLeaderboard(player: Player)
	local stats = GameService:GetPlayerStats(player)
	if not stats then
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end

	local waveVal = leaderstats:FindFirstChild("Wave") :: IntValue?
	if waveVal then
		waveVal.Value = GameService:GetCurrentWave()
	end

	local killsVal = leaderstats:FindFirstChild("Kills") :: IntValue?
	if killsVal then
		killsVal.Value = stats.Kills
	end
end

function StatsService:CalculateSouls(player: Player, wave: number, kills: number, survivalTime: number): number
	local baseSouls = (wave * 10) + math.floor(kills * 0.5) + math.floor(survivalTime / 60) * 5

	-- Bonus for new personal best wave
	local currentBest = PlayerDataService:Read(player, { "HighestWave" }) or 0
	if wave > currentBest then
		baseSouls += 50
	end

	-- Soul Harvest relic bonus
	local soulHarvestTier = PlayerDataService:Read(player, { "RelicLevels", "SoulHarvest" }) or 0
	local soulMult = 1.0 + soulHarvestTier * 0.15
	return math.floor(baseSouls * soulMult)
end

function StatsService:SaveEndOfGame(player: Player)
	local stats = GameService:GetPlayerStats(player)
	if not stats then
		return
	end

	local wave = GameService:GetCurrentWave()
	local survivalTime = GameService:GetGameElapsed()

	-- Update lifetime stats
	local currentBest = PlayerDataService:Read(player, { "HighestWave" }) or 0
	if wave > currentBest then
		PlayerDataService:Write(player, { "HighestWave" }, wave)
		local bestVal = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Best") :: IntValue?
		if bestVal then
			bestVal.Value = wave
		end
	end

	local totalKills = PlayerDataService:Read(player, { "TotalKills" }) or 0
	PlayerDataService:Write(player, { "TotalKills" }, totalKills + stats.Kills)

	local gamesPlayed = PlayerDataService:Read(player, { "TotalGamesPlayed" }) or 0
	PlayerDataService:Write(player, { "TotalGamesPlayed" }, gamesPlayed + 1)

	local totalRuns = PlayerDataService:Read(player, { "TotalRuns" }) or 0
	PlayerDataService:Write(player, { "TotalRuns" }, totalRuns + 1)

	local bestTime = PlayerDataService:Read(player, { "BestSurvivalTime" }) or 0
	if survivalTime > bestTime then
		PlayerDataService:Write(player, { "BestSurvivalTime" }, math.floor(survivalTime))
	end

	-- Calculate and award Souls
	local soulsEarned = self:CalculateSouls(player, wave, stats.Kills, survivalTime)
	local currentSouls = PlayerDataService:Read(player, { "Souls" }) or 0
	local newTotal = currentSouls + soulsEarned
	PlayerDataService:Write(player, { "Souls" }, newTotal)

	self.Client.SoulsEarned:Fire(player, soulsEarned, newTotal)

	-- Check weapon unlock conditions
	self:_checkWeaponUnlocks(player, totalKills + stats.Kills, wave, survivalTime)
end

function StatsService:_checkWeaponUnlocks(player: Player, lifetimeKills: number, bestWave: number, runTime: number)
	local unlocked = PlayerDataService:Read(player, { "UnlockedWeapons" }) or {}
	local stats = GameService:GetPlayerStats(player)
	local runKills = stats and stats.Kills or 0

	local function unlock(weaponId: string)
		if unlocked[weaponId] then
			return
		end
		PlayerDataService:Write(player, { "UnlockedWeapons", weaponId }, true)
		self.Client.WeaponUnlocked:Fire(player, weaponId)
		self.WeaponUnlocked:Fire(player, weaponId)
		unlocked[weaponId] = true
	end

	-- Original weapons
	if not unlocked["Projectile"] and bestWave >= 5 then
		unlock("Projectile")
	end
	if not unlocked["Lightning"] and lifetimeKills >= 200 then
		unlock("Lightning")
	end
	if not unlocked["Aura"] and runTime >= 300 then
		unlock("Aura")
	end

	-- New weapons (VoidWhip and ShadowDaggers are default pool — no unlock needed)
	unlock("VoidWhip")
	unlock("ShadowDaggers")

	if not unlocked["GravityWell"] and lifetimeKills >= 500 then
		unlock("GravityWell")
	end
	if not unlocked["PlagueCloud"] and stats and stats.Level >= 15 then
		unlock("PlagueCloud")
	end
	-- VoidMissiles: kill a boss (checked by boss kill flag, use bestWave >= 5 + runTime >= 120 as proxy)
	if not unlocked["VoidMissiles"] and bestWave >= 5 and runTime >= 120 then
		unlock("VoidMissiles")
	end
	if not unlocked["SpectralScythe"] and runTime >= 600 then
		unlock("SpectralScythe")
	end
	-- SoulDrain: collect 1000 gems (use lifetime XP as proxy — level 15+ implies many gems)
	if not unlocked["SoulDrain"] and stats and stats.Level >= 10 and lifetimeKills >= 300 then
		unlock("SoulDrain")
	end
	if not unlocked["Shockwave"] and runKills >= 50 then
		unlock("Shockwave")
	end
end

function StatsService:GetPlayerSouls(player: Player): number
	return PlayerDataService:Read(player, { "Souls" }) or 0
end

function StatsService:GetUnlockedWeapons(player: Player): { [string]: boolean }
	return PlayerDataService:Read(player, { "UnlockedWeapons" }) or { Orbiter = true }
end

function StatsService:GetRelicLevels(player: Player): { [string]: number }
	return PlayerDataService:Read(player, { "RelicLevels" }) or {}
end

function StatsService:PurchaseRelic(player: Player, relicId: string): (boolean, string?)
	local relic = RelicData.GetRelic(relicId)
	if not relic then
		return false, "Unknown relic"
	end

	local currentTier = PlayerDataService:Read(player, { "RelicLevels", relicId }) or 0
	local cost = RelicData.GetUpgradeCost(relicId, currentTier)
	if not cost then
		return false, "Already max tier"
	end

	local souls = PlayerDataService:Read(player, { "Souls" }) or 0
	if souls < cost then
		return false, "Not enough Souls"
	end

	PlayerDataService:Write(player, { "Souls" }, souls - cost)
	PlayerDataService:Write(player, { "RelicLevels", relicId }, currentTier + 1)
	return true, nil
end

function StatsService:SetSelectedCharacter(player: Player, characterId: string)
	PlayerDataService:Write(player, { "SelectedCharacter" }, characterId)
end

function StatsService:GetSelectedCharacter(player: Player): string
	return PlayerDataService:Read(player, { "SelectedCharacter" }) or "Survivor"
end

function StatsService:GetLifetimeStats(player: Player): { [string]: any }
	return {
		TotalKills = PlayerDataService:Read(player, { "TotalKills" }) or 0,
		BestWave = PlayerDataService:Read(player, { "HighestWave" }) or 0,
		BestSurvivalTime = PlayerDataService:Read(player, { "BestSurvivalTime" }) or 0,
		TotalRuns = PlayerDataService:Read(player, { "TotalRuns" }) or 0,
	}
end

-------------------------------------------------
-- CLIENT API
-------------------------------------------------

function StatsService.Client:GetSouls(player: Player): number
	return self.Server:GetPlayerSouls(player)
end

function StatsService.Client:GetUnlockedWeapons(player: Player): { [string]: boolean }
	return self.Server:GetUnlockedWeapons(player)
end

function StatsService.Client:GetRelicLevels(player: Player): { [string]: number }
	return self.Server:GetRelicLevels(player)
end

function StatsService.Client:PurchaseRelic(player: Player, relicId: string): (boolean, string?)
	return self.Server:PurchaseRelic(player, relicId)
end

function StatsService.Client:SelectCharacter(player: Player, characterId: string)
	self.Server:SetSelectedCharacter(player, characterId)
end

function StatsService.Client:GetSelectedCharacter(player: Player): string
	return self.Server:GetSelectedCharacter(player)
end

function StatsService.Client:GetLifetimeStats(player: Player): { [string]: any }
	return self.Server:GetLifetimeStats(player)
end

function StatsService:KnitInit()
	Players.PlayerAdded:Connect(function(player: Player)
		self:_setupLeaderboard(player)
	end)
end

function StatsService:KnitStart()
	GameService = Knit.GetService("GameService")
	PlayerDataService = Knit.GetService("PlayerDataService")

	-- Load best wave on profile ready
	PlayerDataService.ProfileReady:Connect(function(player: Player)
		task.spawn(function()
			local bestWave = PlayerDataService:Read(player, { "HighestWave" }) or 0
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats then
				local bestVal = leaderstats:FindFirstChild("Best") :: IntValue?
				if bestVal then
					bestVal.Value = bestWave
				end
			end
		end)
	end)

	-- Update leaderboard when stats change
	GameService.GameStateChanged:Connect(function(state: string)
		if state == "GameOver" or state == "Victory" then
			for _, player in Players:GetPlayers() do
				task.spawn(function()
					self:SaveEndOfGame(player)
				end)
			end
		end
	end)

	-- Periodic leaderboard update
	task.spawn(function()
		while true do
			task.wait(2)
			for _, player in Players:GetPlayers() do
				self:UpdateLeaderboard(player)
			end
		end
	end)
end

return StatsService
