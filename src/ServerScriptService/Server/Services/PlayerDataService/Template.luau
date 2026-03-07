--!strict
--[=[
	@class PlayerData
	@server
]=]

export type PlayerData = {
	HighestWave: number,
	TotalKills: number,
	TotalGamesPlayed: number,
}

local playerDataTemplate: PlayerData = {
	HighestWave = 0,
	TotalKills = 0,
	TotalGamesPlayed = 0,
}

return playerDataTemplate
