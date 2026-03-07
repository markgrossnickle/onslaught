--!strict
--[=[
	@class AchievementData
	Achievement definitions and unlock conditions.
]=]

export type AchievementDef = {
	Id: string,
	Name: string,
	Description: string,
	Icon: string, -- emoji/symbol for display
	Reward: number?, -- bonus Souls on unlock
}

local AchievementData = {}

AchievementData.Achievements = {
	-- Kill milestones
	{
		Id = "FirstBlood",
		Name = "First Blood",
		Description = "Kill your first enemy",
		Icon = "⚔",
		Reward = 10,
	},
	{
		Id = "Centurion",
		Name = "Centurion",
		Description = "Kill 100 enemies in a single run",
		Icon = "💯",
		Reward = 50,
	},
	{
		Id = "Slayer",
		Name = "Slayer",
		Description = "Kill 500 enemies in a single run",
		Icon = "🗡",
		Reward = 150,
	},
	{
		Id = "Annihilator",
		Name = "Annihilator",
		Description = "Kill 1000 enemies in a single run",
		Icon = "💀",
		Reward = 500,
	},
	{
		Id = "LifetimeHunter",
		Name = "Lifetime Hunter",
		Description = "Kill 5000 enemies across all runs",
		Icon = "🏆",
		Reward = 300,
	},

	-- Wave milestones
	{
		Id = "Survivor5",
		Name = "Survivor",
		Description = "Reach wave 5",
		Icon = "🛡",
		Reward = 25,
	},
	{
		Id = "Veteran",
		Name = "Veteran",
		Description = "Reach wave 10",
		Icon = "⭐",
		Reward = 75,
	},
	{
		Id = "Elite",
		Name = "Elite",
		Description = "Reach wave 20",
		Icon = "🌟",
		Reward = 200,
	},
	{
		Id = "Legend",
		Name = "Legend",
		Description = "Reach wave 30",
		Icon = "👑",
		Reward = 500,
	},

	-- Time milestones
	{
		Id = "Endurance5",
		Name = "Getting Started",
		Description = "Survive for 5 minutes",
		Icon = "⏱",
		Reward = 25,
	},
	{
		Id = "Endurance10",
		Name = "Holding Strong",
		Description = "Survive for 10 minutes",
		Icon = "⏰",
		Reward = 75,
	},
	{
		Id = "Endurance20",
		Name = "Iron Will",
		Description = "Survive for 20 minutes",
		Icon = "🔥",
		Reward = 300,
	},

	-- Weapon collection
	{
		Id = "Arsenal3",
		Name = "Growing Arsenal",
		Description = "Have 3 weapons active at once",
		Icon = "🔫",
		Reward = 50,
	},
	{
		Id = "Arsenal6",
		Name = "Walking Armory",
		Description = "Have 6 weapons active at once",
		Icon = "💎",
		Reward = 200,
	},
	{
		Id = "FirstEvolution",
		Name = "Evolved",
		Description = "Evolve a weapon for the first time",
		Icon = "✨",
		Reward = 100,
	},

	-- Boss kills
	{
		Id = "BossSlayer",
		Name = "Boss Slayer",
		Description = "Defeat a boss",
		Icon = "🐉",
		Reward = 75,
	},
	{
		Id = "MegaBossSlayer",
		Name = "Void Conqueror",
		Description = "Defeat the Mega Boss",
		Icon = "👹",
		Reward = 500,
	},

	-- Misc
	{
		Id = "MaxLevel",
		Name = "Max Power",
		Description = "Reach max level in a run",
		Icon = "⚡",
		Reward = 100,
	},
	{
		Id = "Collector",
		Name = "Collector",
		Description = "Unlock all weapons",
		Icon = "📦",
		Reward = 500,
	},
	{
		Id = "NoHit",
		Name = "Untouchable",
		Description = "Complete a wave without taking damage",
		Icon = "🌀",
		Reward = 150,
	},
}

function AchievementData.GetAchievement(id: string): AchievementDef?
	for _, achievement in AchievementData.Achievements do
		if achievement.Id == id then
			return achievement
		end
	end
	return nil
end

return table.freeze(AchievementData)
