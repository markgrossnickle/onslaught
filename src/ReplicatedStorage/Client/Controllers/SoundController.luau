--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local SoundController = Knit.CreateController({
	Name = "SoundController",
})

local _sounds: { [string]: Sound } = {}

local SOUND_IDS = {
	Hit = "rbxassetid://12222216",
	EnemyDeath = "rbxassetid://12222230",
	PlayerHurt = "rbxassetid://12222242",
	LevelUp = "rbxassetid://12222253",
	WaveStart = "rbxassetid://12222261",
	GemCollect = "rbxassetid://12222208",
}

function SoundController:_createSounds()
	for name, id in SOUND_IDS do
		local sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = id
		sound.Volume = 0.5
		sound.Parent = SoundService
		_sounds[name] = sound
	end

	if _sounds.GemCollect then
		_sounds.GemCollect.Volume = 0.2
	end
	if _sounds.Hit then
		_sounds.Hit.Volume = 0.4
	end
end

function SoundController:Play(name: string, volumeOverride: number?)
	local sound = _sounds[name]
	if not sound then
		return
	end
	local clone = sound:Clone()
	if volumeOverride then
		clone.Volume = volumeOverride
	end
	clone.Parent = SoundService
	clone:Play()
	clone.Ended:Once(function()
		clone:Destroy()
	end)
	task.delay(5, function()
		if clone and clone.Parent then
			clone:Destroy()
		end
	end)
end

function SoundController:KnitInit()
	self:_createSounds()
end

function SoundController:KnitStart()
	local GameService = Knit.GetService("GameService")
	local EnemyService = Knit.GetService("EnemyService")

	-- Enemy hit
	EnemyService.EnemyDamaged:Connect(function(_model: Model, _damage: number, _position: Vector3)
		self:Play("Hit", 0.15)
	end)

	-- Enemy death
	EnemyService.EnemyKilled:Connect(function(_model: Model, _enemyType: string)
		self:Play("EnemyDeath")
	end)

	-- Player hurt
	GameService.PlayerDamaged:Connect(function(_damage: number)
		self:Play("PlayerHurt")
	end)

	-- Wave start
	GameService.GameStateChanged:Connect(function(state: string, _wave: number)
		if state == "Wave" then
			self:Play("WaveStart")
		end
	end)

	-- XP gem collected
	GameService.XPGemCollected:Connect(function(_amount: number)
		self:Play("GemCollect")
	end)

	-- Level up
	GameService.ShowUpgradeCards:Connect(function(_cards: any)
		self:Play("LevelUp")
	end)
end

return SoundController
