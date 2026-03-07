--!strict
--[=[
	@class RelicData
	Persistent upgrade definitions purchasable with Souls.
]=]

export type RelicDef = {
	Id: string,
	Name: string,
	Description: string,
	MaxTier: number,
	Costs: { number }, -- cost per tier
	EffectPerTier: string, -- display text
}

local RelicData = {}

RelicData.Relics = {
	{
		Id = "ToughSkin",
		Name = "Tough Skin",
		Description = "+10 Max HP per tier",
		MaxTier = 5,
		Costs = { 50, 100, 200, 400, 800 },
		EffectPerTier = "+10 Max HP",
	},
	{
		Id = "SwiftFeet",
		Name = "Swift Feet",
		Description = "+5% Move Speed per tier",
		MaxTier = 5,
		Costs = { 50, 100, 200, 400, 800 },
		EffectPerTier = "+5% Move Speed",
	},
	{
		Id = "KeenEdge",
		Name = "Keen Edge",
		Description = "+8% All Damage per tier",
		MaxTier = 5,
		Costs = { 75, 150, 300, 600, 1200 },
		EffectPerTier = "+8% Damage",
	},
	{
		Id = "MagneticPull",
		Name = "Magnetic Pull",
		Description = "+15% Magnet Range per tier",
		MaxTier = 5,
		Costs = { 40, 80, 160, 320, 640 },
		EffectPerTier = "+15% Magnet Range",
	},
	{
		Id = "QuickLearner",
		Name = "Quick Learner",
		Description = "+10% XP Gain per tier",
		MaxTier = 3,
		Costs = { 100, 300, 900 },
		EffectPerTier = "+10% XP",
	},
	{
		Id = "Regeneration",
		Name = "Regeneration",
		Description = "+1 HP/s Regen per tier",
		MaxTier = 3,
		Costs = { 150, 450, 1350 },
		EffectPerTier = "+1 HP/s",
	},
	{
		Id = "LastStand",
		Name = "Last Stand",
		Description = "Survive one killing blow per run (1 HP)",
		MaxTier = 1,
		Costs = { 500 },
		EffectPerTier = "1 free death save",
	},
	{
		Id = "SoulHarvest",
		Name = "Soul Harvest",
		Description = "+15% Souls earned per tier",
		MaxTier = 3,
		Costs = { 200, 600, 1800 },
		EffectPerTier = "+15% Souls",
	},
	{
		Id = "VoidArmor",
		Name = "Void Armor",
		Description = "-5% damage taken per tier",
		MaxTier = 5,
		Costs = { 100, 200, 400, 800, 1600 },
		EffectPerTier = "-5% Damage Taken",
	},
	{
		Id = "CriticalStrike",
		Name = "Critical Strike",
		Description = "+5% critical hit chance per tier (2x damage)",
		MaxTier = 5,
		Costs = { 100, 200, 400, 800, 1600 },
		EffectPerTier = "+5% Crit Chance",
	},
	{
		Id = "Bloodlust",
		Name = "Bloodlust",
		Description = "+1 HP heal on kill per tier",
		MaxTier = 3,
		Costs = { 150, 450, 1350 },
		EffectPerTier = "+1 HP on Kill",
	},
	{
		Id = "ExplosiveFinish",
		Name = "Explosive Finish",
		Description = "Enemies explode on death dealing 5 damage per tier in a 5-stud radius",
		MaxTier = 3,
		Costs = { 200, 600, 1800 },
		EffectPerTier = "+5 Explosion Damage",
	},
	{
		Id = "EvolutionMaster",
		Name = "Evolution Master",
		Description = "Weapons evolve 1 level earlier per tier",
		MaxTier = 2,
		Costs = { 500, 1500 },
		EffectPerTier = "-1 Evo Level Req",
	},
	{
		Id = "GemMagnet",
		Name = "Gem Magnet",
		Description = "+20% gem value per tier",
		MaxTier = 3,
		Costs = { 100, 300, 900 },
		EffectPerTier = "+20% Gem Value",
	},
	{
		Id = "Revitalize",
		Name = "Revitalize",
		Description = "-1s respawn delay per tier",
		MaxTier = 3,
		Costs = { 75, 225, 675 },
		EffectPerTier = "-1s Respawn",
	},
	{
		Id = "WeaponMastery",
		Name = "Weapon Mastery",
		Description = "+3% attack speed per tier",
		MaxTier = 5,
		Costs = { 100, 200, 400, 800, 1600 },
		EffectPerTier = "+3% Attack Speed",
	},
}

function RelicData.GetRelic(id: string): RelicDef?
	for _, relic in RelicData.Relics do
		if relic.Id == id then
			return relic
		end
	end
	return nil
end

function RelicData.GetUpgradeCost(id: string, currentTier: number): number?
	local relic = RelicData.GetRelic(id)
	if not relic then
		return nil
	end
	local nextTier = currentTier + 1
	if nextTier > relic.MaxTier then
		return nil
	end
	return relic.Costs[nextTier]
end

return table.freeze(RelicData)
