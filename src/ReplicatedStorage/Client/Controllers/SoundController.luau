--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local SoundController = Knit.CreateController({
	Name = "SoundController",
})

local _sounds: { [string]: Sound } = {}

local SOUND_IDS = {
	Swing = "rbxassetid://12222208",
	Hit = "rbxassetid://12222216",
	EnemyDeath = "rbxassetid://12222230",
	PlayerHurt = "rbxassetid://12222242",
	LevelUp = "rbxassetid://12222253",
	WaveStart = "rbxassetid://12222261",
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

	-- Adjust volumes
	if _sounds.Swing then
		_sounds.Swing.Volume = 0.3
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
	-- Clone for overlapping plays
	local clone = sound:Clone()
	if volumeOverride then
		clone.Volume = volumeOverride
	end
	clone.Parent = SoundService
	clone:Play()
	clone.Ended:Once(function()
		clone:Destroy()
	end)
	-- Safety cleanup
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
	local CombatService = Knit.GetService("CombatService")
	local EnemyService = Knit.GetService("EnemyService")

	-- Attack swing
	CombatService.AttackResult:Connect(function(hitCount: number, _position: Vector3, _direction: Vector3)
		self:Play("Swing")
		if hitCount > 0 then
			task.delay(0.05, function()
				self:Play("Hit")
			end)
		end
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
end

return SoundController
