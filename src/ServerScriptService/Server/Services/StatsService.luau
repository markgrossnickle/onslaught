--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local StatsService = Knit.CreateService({
	Name = "StatsService",
	Client = {},
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

function StatsService:SaveEndOfGame(player: Player)
	local stats = GameService:GetPlayerStats(player)
	if not stats then
		return
	end

	local wave = GameService:GetCurrentWave()
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
		if state == "GameOver" then
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
