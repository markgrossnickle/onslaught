--!strict
--[=[
	@class CharacterData
	Character definitions for the character selection system.
]=]

export type CharacterDef = {
	Id: string,
	Name: string,
	Description: string,
	StartingWeapon: string, -- weapon key from GameConfig.Weapons
	Color: Color3,
	Passive: { [string]: number },
}

local CharacterData = {}

CharacterData.Characters = {
	{
		Id = "Survivor",
		Name = "Survivor",
		Description = "+20% XP gain",
		StartingWeapon = "Orbiter",
		Color = Color3.fromRGB(80, 140, 255),
		Passive = {
			XPMult = 1.2,
		},
	},
	{
		Id = "Berserker",
		Name = "Berserker",
		Description = "+15% damage, -10% max HP, +2 starting orbiters",
		StartingWeapon = "Orbiter",
		Color = Color3.fromRGB(220, 60, 60),
		Passive = {
			DamageMult = 1.15,
			MaxHealthMult = 0.9,
			ExtraOrbiters = 2,
		},
	},
	{
		Id = "Guardian",
		Name = "Guardian",
		Description = "+30% max HP, -10% move speed. Starts with Aura if unlocked.",
		StartingWeapon = "Aura",
		Color = Color3.fromRGB(60, 200, 80),
		Passive = {
			MaxHealthMult = 1.3,
			SpeedMult = 0.9,
		},
	},
}

function CharacterData.GetCharacter(id: string): CharacterDef?
	for _, char in CharacterData.Characters do
		if char.Id == id then
			return char
		end
	end
	return nil
end

return table.freeze(CharacterData)
