--!strict
--[=[
	@class VoidArenaController
	Client-side arena evolution: veins pulse brighter, fog creeps in,
	crystals emit particles, dark flickers as the run progresses.
]=]
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local PlatformUtil = require(ReplicatedStorage.Shared.PlatformUtil)

local Player = Players.LocalPlayer

local VoidArenaController = Knit.CreateController({
	Name = "VoidArenaController",
})

local _currentPhase = 1
local _gameElapsed = 0
local _lastFlickerTime = 0
local _veinFrameSkip = 0

function VoidArenaController:_getPhase(): number
	local cfg = GameConfig.Arena
	if _gameElapsed >= cfg.Phase4Time then
		return 4
	elseif _gameElapsed >= cfg.Phase3Time then
		return 3
	elseif _gameElapsed >= cfg.Phase2Time then
		return 2
	end
	return 1
end

function VoidArenaController:_updatePhase(phase: number)
	if phase == _currentPhase then
		return
	end
	_currentPhase = phase

	local cfg = GameConfig.Arena
	local fogEnd = cfg.FogEndPhase1
	if phase == 2 then
		fogEnd = cfg.FogEndPhase2
	elseif phase == 3 then
		fogEnd = cfg.FogEndPhase3
	elseif phase >= 4 then
		fogEnd = cfg.FogEndPhase4
	end

	-- Tween fog
	TweenService:Create(Lighting, TweenInfo.new(5), { FogEnd = fogEnd }):Play()

	-- Dim ambient slightly in later phases (still visible)
	if phase == 3 then
		TweenService:Create(Lighting, TweenInfo.new(3), {
			Ambient = Color3.fromRGB(55, 35, 70),
			OutdoorAmbient = Color3.fromRGB(45, 30, 60),
		}):Play()
	elseif phase >= 4 then
		TweenService:Create(Lighting, TweenInfo.new(3), {
			Ambient = Color3.fromRGB(40, 25, 55),
			OutdoorAmbient = Color3.fromRGB(35, 22, 48),
		}):Play()
	end

	-- Phase 3+: crystals start emitting particles
	if phase >= 3 then
		self:_enableCrystalParticles()
	end

	-- Phase 4: floor particles
	if phase >= 4 then
		self:_enableFloorParticles()
	end
end

function VoidArenaController:_enableCrystalParticles()
	local arenaFolder = workspace:FindFirstChild("Arena")
	if not arenaFolder then
		return
	end

	for _, child in arenaFolder:GetChildren() do
		if child:IsA("Model") and child.Name:sub(1, 7) == "Crystal" then
			local core = child:FindFirstChild("CrystalCore") :: BasePart?
			local target = core or child.PrimaryPart
			if target and not target:FindFirstChild("CrystalSmoke") then
				local emitter = Instance.new("ParticleEmitter")
				emitter.Name = "CrystalSmoke"
				emitter.Color = ColorSequence.new(Color3.fromRGB(100, 30, 150), Color3.fromRGB(0, 0, 0))
				emitter.Size =
					NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1.5) })
				emitter.Transparency =
					NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
				emitter.Lifetime = NumberRange.new(1, 2)
				emitter.Rate = 3
				emitter.Speed = NumberRange.new(0.5, 1.5)
				emitter.EmissionDirection = Enum.NormalId.Top
				emitter.Parent = target
			end
		end
	end
end

function VoidArenaController:_enableFloorParticles()
	local arenaFolder = workspace:FindFirstChild("Arena")
	if not arenaFolder then
		return
	end

	local floor = arenaFolder:FindFirstChild("Floor") :: BasePart?
	if floor and not floor:FindFirstChild("FloorRise") then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "FloorRise"
		emitter.Color = ColorSequence.new(Color3.fromRGB(60, 20, 90), Color3.fromRGB(0, 0, 0))
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 2) })
		emitter.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
		emitter.Lifetime = NumberRange.new(2, 4)
		emitter.Rate = 15
		emitter.Speed = NumberRange.new(1, 3)
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.SpreadAngle = Vector2.new(30, 30)
		emitter.Parent = floor
	end
end

function VoidArenaController:_updateVeins(now: number)
	local arenaFolder = workspace:FindFirstChild("Arena")
	if not arenaFolder then
		return
	end

	local veinFolder = arenaFolder:FindFirstChild("GroundVeins")
	if not veinFolder then
		return
	end

	-- Phase 1: dim (transparency 0.4)
	-- Phase 2: pulse (oscillate 0.2-0.5)
	-- Phase 3: bright pulse (0.0-0.3)
	-- Phase 4: rapid pulse (0.0-0.2)
	for _, vein in veinFolder:GetChildren() do
		if not vein:IsA("BasePart") then
			continue
		end

		if _currentPhase == 1 then
			vein.Transparency = 0.4
		elseif _currentPhase == 2 then
			vein.Transparency = 0.35 + math.sin(now * 1.5 + vein.Position.X * 0.3) * 0.15
		elseif _currentPhase == 3 then
			vein.Transparency = 0.15 + math.sin(now * 2.5 + vein.Position.X * 0.3) * 0.15
		else
			vein.Transparency = 0.1 + math.sin(now * 5 + vein.Position.X * 0.3) * 0.1
		end
	end
end

function VoidArenaController:_tryDarkFlicker(now: number)
	-- Phase 3+: occasional dark flicker at screen edges
	if _currentPhase < 3 then
		return
	end

	local interval = if _currentPhase >= 4 then 4 else 8
	if now - _lastFlickerTime < interval then
		return
	end

	if math.random() > 0.3 then
		_lastFlickerTime = now
		return
	end

	_lastFlickerTime = now

	local PlayerGui = Player:WaitForChild("PlayerGui")
	local hudGui = PlayerGui:FindFirstChild("OnslaughtHUD") :: ScreenGui?
	if not hudGui then
		return
	end

	local flicker = Instance.new("Frame")
	flicker.Name = "DarkFlicker"
	flicker.Size = UDim2.new(1, 0, 1, 0)
	flicker.BackgroundColor3 = Color3.fromRGB(10, 0, 15)
	flicker.BackgroundTransparency = 0.85
	flicker.BorderSizePixel = 0
	flicker.ZIndex = 85
	flicker.Parent = hudGui

	TweenService:Create(flicker, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
	task.delay(0.15, function()
		flicker:Destroy()
	end)
end

function VoidArenaController:_pushPlayerInBounds()
	local char = Player.Character
	if not char then
		return
	end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local radius = GameConfig.Arena.Radius - 2
	local pos = root.Position
	local dist = math.sqrt(pos.X * pos.X + pos.Z * pos.Z)

	if dist > radius then
		local scale = radius / dist
		local newPos = Vector3.new(pos.X * scale, pos.Y, pos.Z * scale)
		root.CFrame = CFrame.new(newPos) * (root.CFrame - root.CFrame.Position)
	end
end

function VoidArenaController:_spawnHazardVFX(hazardType: string, position: Vector3, radius: number, duration: number)
	local arenaFolder = workspace:FindFirstChild("Arena")
	if not arenaFolder then
		return
	end

	local color = Color3.fromRGB(255, 100, 30) -- lava default
	if hazardType == "IcePatches" then
		color = Color3.fromRGB(100, 180, 255)
	elseif hazardType == "VoidRifts" then
		color = Color3.fromRGB(80, 255, 120)
	end

	local indicator = Instance.new("Part")
	indicator.Name = "HazardZone"
	indicator.Shape = Enum.PartType.Cylinder
	indicator.Size = Vector3.new(0.2, radius * 2, radius * 2)
	indicator.Color = color
	indicator.Material = Enum.Material.Neon
	indicator.Transparency = 0.6
	indicator.Anchored = true
	indicator.CanCollide = false
	indicator.CastShadow = false
	indicator.CFrame = CFrame.new(position.X, 0.15, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	indicator.Parent = arenaFolder

	-- Pulse effect
	task.spawn(function()
		local elapsed = 0
		while elapsed < duration and indicator.Parent do
			elapsed += task.wait(0.1)
			indicator.Transparency = 0.5 + math.sin(elapsed * 4) * 0.15
		end
		if indicator.Parent then
			indicator:Destroy()
		end
	end)
end

function VoidArenaController:_onStageChanged(stageName: string, _stageIndex: number)
	-- Update lighting based on stage config
	local stages = GameConfig.Stages.List
	for _, stage in stages do
		if stage.Name == stageName then
			TweenService:Create(Lighting, TweenInfo.new(3), {
				FogColor = stage.FogColor,
				Ambient = stage.Ambient,
				OutdoorAmbient = stage.OutdoorAmbient or stage.Ambient,
			}):Play()

			local cc = Lighting:FindFirstChild("VoidColorCorrection") :: ColorCorrectionEffect?
			if cc then
				TweenService:Create(cc, TweenInfo.new(3), { TintColor = stage.TintColor }):Play()
			end
			break
		end
	end
end

function VoidArenaController:KnitInit() end

function VoidArenaController:KnitStart()
	local GameService = Knit.GetService("GameService")
	local ArenaService = Knit.GetService("ArenaService")

	GameService.GameTimerTick:Connect(function(elapsed: number)
		_gameElapsed = elapsed
	end)

	-- Reset on new game
	GameService.GameStateChanged:Connect(function(state: string)
		if state == "Lobby" or state == "WaitingForPlayers" then
			_currentPhase = 1
			_gameElapsed = 0
			Lighting.FogEnd = GameConfig.Arena.FogEndPhase1
			Lighting.Ambient = Color3.fromRGB(80, 50, 100)
			Lighting.OutdoorAmbient = Color3.fromRGB(60, 40, 80)

			-- Remove floor/crystal particles
			local arenaFolder = workspace:FindFirstChild("Arena")
			if arenaFolder then
				local floor = arenaFolder:FindFirstChild("Floor") :: BasePart?
				if floor then
					local floorRise = floor:FindFirstChild("FloorRise")
					if floorRise then
						floorRise:Destroy()
					end
				end
				for _, child in arenaFolder:GetChildren() do
					if child:IsA("Model") and child.Name:sub(1, 7) == "Crystal" then
						for _, part in child:GetChildren() do
							if part:IsA("BasePart") then
								local smoke = part:FindFirstChild("CrystalSmoke")
								if smoke then
									smoke:Destroy()
								end
							end
						end
					end
				end
			end
		end
	end)

	-- Stage change and hazard signals
	ArenaService.StageChanged:Connect(function(stageName: string, stageIndex: number)
		self:_onStageChanged(stageName, stageIndex)
	end)

	ArenaService.HazardSpawned:Connect(function(hazardType: string, position: Vector3, radius: number, duration: number)
		self:_spawnHazardVFX(hazardType, position, radius, duration)
	end)

	local isMobile = PlatformUtil.IsMobile()

	RunService.RenderStepped:Connect(function(_dt)
		local now = tick()

		-- Update phase
		local phase = self:_getPhase()
		self:_updatePhase(phase)

		-- Update vein pulsing (skip every other frame on mobile)
		_veinFrameSkip += 1
		if not isMobile or _veinFrameSkip % 2 == 0 then
			self:_updateVeins(now)
		end

		-- Dark flicker
		self:_tryDarkFlicker(now)

		-- Push player into bounds
		self:_pushPlayerInBounds()
	end)
end

return VoidArenaController
