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
		Description = "+30% max HP, -10% move speed. Starts with Aura.",
		StartingWeapon = "Aura",
		Color = Color3.fromRGB(60, 200, 80),
		Passive = {
			MaxHealthMult = 1.3,
			SpeedMult = 0.9,
		},
	},
	{
		Id = "Shade",
		Name = "Shade",
		Description = "+20% move speed, -15% max HP. Starts with Shadow Daggers.",
		StartingWeapon = "ShadowDaggers",
		Color = Color3.fromRGB(60, 30, 80),
		Passive = {
			SpeedMult = 1.2,
			MaxHealthMult = 0.85,
		},
	},
	{
		Id = "Warlock",
		Name = "Warlock",
		Description = "+25% damage, -20% max HP. Starts with Void Whip.",
		StartingWeapon = "VoidWhip",
		Color = Color3.fromRGB(120, 40, 180),
		Passive = {
			DamageMult = 1.25,
			MaxHealthMult = 0.8,
		},
	},
	{
		Id = "Engineer",
		Name = "Engineer",
		Description = "+40% area of effect, -10% damage. Starts with Gravity Well.",
		StartingWeapon = "GravityWell",
		Color = Color3.fromRGB(220, 180, 40),
		Passive = {
			AreaMult = 1.4,
			DamageMult = 0.9,
		},
	},
	{
		Id = "Plague Doctor",
		Name = "Plague Doctor",
		Description = "3 HP/s regen, -10% move speed. Starts with Plague Cloud.",
		StartingWeapon = "PlagueCloud",
		Color = Color3.fromRGB(40, 180, 60),
		Passive = {
			HealthRegen = 3,
			SpeedMult = 0.9,
		},
	},
	{
		Id = "Gunslinger",
		Name = "Gunslinger",
		Description = "+20% attack speed, -5% damage. Starts with Projectile.",
		StartingWeapon = "Projectile",
		Color = Color3.fromRGB(200, 120, 40),
		Passive = {
			CooldownMult = 0.8,
			DamageMult = 0.95,
		},
	},
	{
		Id = "Necromancer",
		Name = "Necromancer",
		Description = "+15% soul harvest, +30% XP. Starts with Soul Drain.",
		StartingWeapon = "SoulDrain",
		Color = Color3.fromRGB(40, 60, 40),
		Passive = {
			XPMult = 1.3,
			SoulMult = 1.15,
		},
	},
	{
		Id = "Titan",
		Name = "Titan",
		Description = "+50% max HP, -25% move speed, +20% damage. Starts with Shockwave.",
		StartingWeapon = "Shockwave",
		Color = Color3.fromRGB(100, 80, 60),
		Passive = {
			MaxHealthMult = 1.5,
			SpeedMult = 0.75,
			DamageMult = 1.2,
		},
	},
	{
		Id = "Phantom",
		Name = "Phantom",
		Description = "+30% move speed, +15% damage, -25% max HP. Starts with Spectral Scythe.",
		StartingWeapon = "SpectralScythe",
		Color = Color3.fromRGB(180, 180, 220),
		Passive = {
			SpeedMult = 1.3,
			DamageMult = 1.15,
			MaxHealthMult = 0.75,
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
