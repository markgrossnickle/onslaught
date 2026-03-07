--!strict
--[=[
	@class PlayerData
	@server
]=]

export type PlayerData = {
	HighestWave: number,
	TotalKills: number,
	TotalGamesPlayed: number,
	BestSurvivalTime: number,
	TotalRuns: number,

	-- Meta-currency
	Souls: number,

	-- Persistent relic upgrades: relicId -> tier (0 = not purchased)
	RelicLevels: { [string]: number },

	-- Unlocked weapons
	UnlockedWeapons: { [string]: boolean },

	-- Selected character
	SelectedCharacter: string,

	-- Achievements: achievementId -> true
	UnlockedAchievements: { [string]: boolean },
}

local playerDataTemplate: PlayerData = {
	HighestWave = 0,
	TotalKills = 0,
	TotalGamesPlayed = 0,
	BestSurvivalTime = 0,
	TotalRuns = 0,

	Souls = 0,

	RelicLevels = {},

	UnlockedWeapons = {
		Orbiter = true,
	},

	SelectedCharacter = "Survivor",

	UnlockedAchievements = {},
}

return playerDataTemplate
