--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local ArenaService = Knit.CreateService({
	Name = "ArenaService",
	Client = {
		StageChanged = Knit.CreateSignal(), -- (stageName: string, stageIndex: number)
		HazardSpawned = Knit.CreateSignal(), -- (hazardType: string, position: Vector3, radius: number, duration: number)
	},
})

local ArenaFolder: Folder = nil :: any
local _currentStageIndex: number = 1
local _hazardActive: boolean = false
local GameService: any

function ArenaService:_createPart(
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	anchored: boolean?
): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Anchored = if anchored ~= nil then anchored else true
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = ArenaFolder
	return part
end

function ArenaService:BuildArena()
	if ArenaFolder then
		ArenaFolder:Destroy()
	end
	ArenaFolder = Instance.new("Folder")
	ArenaFolder.Name = "Arena"
	ArenaFolder.Parent = workspace

	local cfg = GameConfig.Arena

	-- Floor (circular, but using large Part -- circular boundary enforces actual shape)
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Shape = Enum.PartType.Cylinder
	floor.Size = Vector3.new(cfg.FloorSize.Y, cfg.Radius * 2 + 10, cfg.Radius * 2 + 10)
	floor.CFrame = CFrame.new(cfg.FloorPosition) * CFrame.Angles(0, 0, math.rad(90))
	floor.Color = cfg.FloorColor
	floor.Material = cfg.FloorMaterial or Enum.Material.Slate
	floor.Anchored = true
	floor.TopSurface = Enum.SurfaceType.Smooth
	floor.BottomSurface = Enum.SurfaceType.Smooth
	floor.Parent = ArenaFolder

	-- Ground veins (glowing magenta Neon cracks)
	self:_spawnGroundVeins()

	-- Void boundary wall (ring of transparent dark Parts)
	self:_spawnBoundaryWall()

	-- Void crystal obstacles
	self:_spawnCrystals()

	-- Lighting
	self:_setupLighting()
end

function ArenaService:_spawnGroundVeins()
	local cfg = GameConfig.Arena
	local rng = Random.new()

	local veinFolder = Instance.new("Folder")
	veinFolder.Name = "GroundVeins"
	veinFolder.Parent = ArenaFolder

	for i = 1, cfg.VeinCount do
		local length = rng:NextNumber(cfg.VeinMinLength, cfg.VeinMaxLength)
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(5, cfg.Radius - 10)
		local x = math.cos(angle) * dist
		local z = math.sin(angle) * dist
		local rotation = rng:NextNumber(0, math.pi * 2)

		local vein = Instance.new("Part")
		vein.Name = "Vein" .. i
		vein.Size = Vector3.new(length, 0.1, 0.3 + rng:NextNumber(0, 0.3))
		vein.Color = cfg.VeinColor
		vein.Material = Enum.Material.Neon
		vein.Anchored = true
		vein.CanCollide = false
		vein.CastShadow = false
		vein.Transparency = 0.4
		vein.CFrame = CFrame.new(x, 0.06, z) * CFrame.Angles(0, rotation, 0)
		vein.Parent = veinFolder
	end
end

function ArenaService:_spawnBoundaryWall()
	local cfg = GameConfig.Arena
	local segments = cfg.BoundarySegments
	local radius = cfg.Radius

	local boundaryFolder = Instance.new("Folder")
	boundaryFolder.Name = "Boundary"
	boundaryFolder.Parent = ArenaFolder

	-- Calculate segment width to form a ring
	local circumference = 2 * math.pi * radius
	local segWidth = circumference / segments + 1 -- slight overlap

	for i = 1, segments do
		local angle = (i / segments) * math.pi * 2
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius

		local wall = Instance.new("Part")
		wall.Name = "BoundaryWall" .. i
		wall.Size = Vector3.new(segWidth, cfg.BoundaryHeight, 2)
		wall.Color = cfg.BoundaryColor
		wall.Material = Enum.Material.Glass
		wall.Transparency = cfg.BoundaryTransparency
		wall.Anchored = true
		wall.CanCollide = true
		wall.CFrame = CFrame.lookAt(Vector3.new(x, cfg.BoundaryHeight / 2, z), Vector3.zero)
		wall.Parent = boundaryFolder

		-- Dark smoke emitter on every 4th segment
		if i % 4 == 0 then
			local emitter = Instance.new("ParticleEmitter")
			emitter.Name = "BoundarySmoke"
			emitter.Color = ColorSequence.new(cfg.BoundarySmokeColor, Color3.fromRGB(0, 0, 0))
			emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 4) })
			emitter.Transparency =
				NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
			emitter.Lifetime = NumberRange.new(2, 4)
			emitter.Rate = 4
			emitter.Speed = NumberRange.new(1, 3)
			emitter.SpreadAngle = Vector2.new(20, 20)
			emitter.EmissionDirection = Enum.NormalId.Top
			emitter.Parent = wall
		end
	end
end

function ArenaService:_spawnCrystals()
	local cfg = GameConfig.Arena
	local rng = Random.new()

	for i = 1, cfg.CrystalCount do
		-- Position within circle, avoiding center
		local angle = rng:NextNumber(0, math.pi * 2)
		local margin = cfg.CrystalSpawnMargin
		local dist = rng:NextNumber(margin, cfg.Radius - 15)
		local x = math.cos(angle) * dist
		local z = math.sin(angle) * dist

		-- Keep away from center spawn
		if math.abs(x) < margin and math.abs(z) < margin then
			x += (if x >= 0 then margin else -margin)
		end

		local clusterModel = Instance.new("Model")
		clusterModel.Name = "Crystal" .. i
		clusterModel.Parent = ArenaFolder

		-- Main crystal shard (WedgePart)
		local height = rng:NextNumber(cfg.CrystalMinHeight, cfg.CrystalMaxHeight)
		local baseWidth = height * 0.3 + rng:NextNumber(0.5, 1.5)

		local mainShard = Instance.new("WedgePart")
		mainShard.Name = "MainShard"
		mainShard.Size = Vector3.new(baseWidth, height, baseWidth * 0.8)
		mainShard.Color = cfg.CrystalColor
		mainShard.Material = Enum.Material.SmoothPlastic
		mainShard.Anchored = true
		mainShard.CanCollide = true
		mainShard.CFrame = CFrame.new(x, height / 2, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		mainShard.Parent = clusterModel

		-- Secondary shards (1-3)
		local shardCount = rng:NextInteger(1, 3)
		for s = 1, shardCount do
			local sHeight = height * rng:NextNumber(0.3, 0.7)
			local sWidth = sHeight * 0.25

			local shard = Instance.new("WedgePart")
			shard.Name = "Shard" .. s
			shard.Size = Vector3.new(sWidth, sHeight, sWidth * 0.8)
			shard.Color = cfg.CrystalColor
			shard.Material = Enum.Material.SmoothPlastic
			shard.Anchored = true
			shard.CanCollide = true

			local sAngle = rng:NextNumber(0, math.pi * 2)
			local sDist = baseWidth * 0.6 + rng:NextNumber(0.5, 1.5)
			shard.CFrame = CFrame.new(x + math.cos(sAngle) * sDist, sHeight / 2, z + math.sin(sAngle) * sDist)
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.15, 0.15))
			shard.Parent = clusterModel
		end

		-- Dim magenta core inside (50% chance)
		if rng:NextNumber() > 0.5 then
			local core = Instance.new("Part")
			core.Name = "CrystalCore"
			core.Shape = Enum.PartType.Ball
			core.Size = Vector3.one * (baseWidth * 0.4)
			core.Color = cfg.CrystalCoreColor
			core.Material = Enum.Material.Neon
			core.Transparency = 0.3
			core.Anchored = true
			core.CanCollide = false
			core.CastShadow = false
			core.Position = Vector3.new(x, height * 0.3, z)
			core.Parent = clusterModel
		end

		clusterModel.PrimaryPart = mainShard
	end
end

function ArenaService:_setupLighting()
	local lighting = game:GetService("Lighting")
	lighting.Ambient = Color3.fromRGB(20, 10, 30)
	lighting.OutdoorAmbient = Color3.fromRGB(15, 8, 20)
	lighting.Brightness = 0.5
	lighting.ClockTime = 0
	lighting.FogEnd = GameConfig.Arena.FogEndPhase1
	lighting.FogColor = Color3.fromRGB(10, 5, 15)
	lighting.EnvironmentDiffuseScale = 0
	lighting.EnvironmentSpecularScale = 0

	-- Purple color correction
	local existing = lighting:FindFirstChild("VoidColorCorrection")
	if existing then
		existing:Destroy()
	end

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "VoidColorCorrection"
	cc.TintColor = Color3.fromRGB(220, 190, 255)
	cc.Saturation = -0.1
	cc.Contrast = 0.1
	cc.Brightness = -0.05
	cc.Parent = lighting
end

function ArenaService:GetArenaFolder(): Folder
	return ArenaFolder
end

function ArenaService:GetCurrentStage(): { [string]: any }
	local stages = GameConfig.Stages.List
	return stages[_currentStageIndex]
end

function ArenaService:GetCurrentStageIndex(): number
	return _currentStageIndex
end

function ArenaService:TransitionToStage(stageIndex: number)
	local stages = GameConfig.Stages.List
	if stageIndex < 1 or stageIndex > #stages then
		return
	end
	if stageIndex == _currentStageIndex then
		return
	end

	_currentStageIndex = stageIndex
	local stage = stages[stageIndex]

	-- Update floor color
	local floor = ArenaFolder and ArenaFolder:FindFirstChild("Floor") :: BasePart?
	if floor then
		floor.Color = stage.FloorColor
		floor.Material = stage.FloorMaterial
	end

	-- Update veins
	local veinFolder = ArenaFolder and ArenaFolder:FindFirstChild("GroundVeins")
	if veinFolder then
		for _, vein in veinFolder:GetChildren() do
			if vein:IsA("BasePart") then
				vein.Color = stage.VeinColor
			end
		end
	end

	-- Update crystals
	if ArenaFolder then
		for _, child in ArenaFolder:GetChildren() do
			if child:IsA("Model") and child.Name:sub(1, 7) == "Crystal" then
				for _, part in child:GetChildren() do
					if part:IsA("BasePart") then
						if part.Name == "CrystalCore" then
							part.Color = stage.CrystalCoreColor
						else
							part.Color = stage.CrystalColor
						end
					end
				end
			end
		end
	end

	-- Update boundary
	local boundaryFolder = ArenaFolder and ArenaFolder:FindFirstChild("Boundary")
	if boundaryFolder then
		for _, wall in boundaryFolder:GetChildren() do
			if wall:IsA("BasePart") then
				wall.Color = stage.BoundaryColor
				local smoke = wall:FindFirstChild("BoundarySmoke") :: ParticleEmitter?
				if smoke then
					smoke.Color = ColorSequence.new(stage.BoundarySmokeColor, Color3.fromRGB(0, 0, 0))
				end
			end
		end
	end

	-- Update lighting
	local lighting = game:GetService("Lighting")
	lighting.FogColor = stage.FogColor
	lighting.Ambient = stage.Ambient
	lighting.OutdoorAmbient = stage.Ambient

	local cc = lighting:FindFirstChild("VoidColorCorrection") :: ColorCorrectionEffect?
	if cc then
		cc.TintColor = stage.TintColor
	end

	-- Notify clients
	self.Client.StageChanged:FireAll(stage.Name, stageIndex)
end

function ArenaService:_spawnHazard()
	local stage = self:GetCurrentStage()
	if stage.Hazard == "None" then
		return
	end

	local Players = game:GetService("Players")
	local rng = Random.new()
	local radius = GameConfig.Arena.Radius

	for _ = 1, stage.HazardCount or 1 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(10, radius - 15)
		local pos = Vector3.new(math.cos(angle) * dist, 0.1, math.sin(angle) * dist)
		local hazardRadius = stage.HazardRadius or 6
		local duration = stage.HazardDuration or 8

		self.Client.HazardSpawned:FireAll(stage.Hazard, pos, hazardRadius, duration)

		if stage.Hazard == "LavaPools" then
			task.spawn(function()
				local elapsed = 0
				while elapsed < duration do
					local dt = task.wait(1)
					elapsed += dt
					for _, player in Players:GetPlayers() do
						local stats = GameService:GetPlayerStats(player)
						if stats and stats.Health > 0 then
							local char = player.Character
							if char then
								local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
								if root and (root.Position - pos).Magnitude <= hazardRadius then
									GameService:DamagePlayer(player, stage.HazardDamage or 8)
								end
							end
						end
					end
				end
			end)
		elseif stage.Hazard == "IcePatches" then
			task.spawn(function()
				local elapsed = 0
				while elapsed < duration do
					local dt = task.wait(0.5)
					elapsed += dt
					for _, player in Players:GetPlayers() do
						local char = player.Character
						if char then
							local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
							local hum = char:FindFirstChildOfClass("Humanoid")
							if root and hum and (root.Position - pos).Magnitude <= hazardRadius then
								hum.WalkSpeed = GameConfig.Player.BaseWalkSpeed * (stage.HazardSlowFactor or 0.5)
							end
						end
					end
				end
				-- Restore speed
				for _, player in Players:GetPlayers() do
					local char = player.Character
					if char then
						local hum = char:FindFirstChildOfClass("Humanoid")
						if hum then
							hum.WalkSpeed = GameConfig.Player.BaseWalkSpeed
						end
					end
				end
			end)
		elseif stage.Hazard == "VoidRifts" then
			task.spawn(function()
				local elapsed = 0
				while elapsed < duration do
					local dt = task.wait(1)
					elapsed += dt
					for _, player in Players:GetPlayers() do
						local char = player.Character
						if char then
							local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
							if root and (root.Position - pos).Magnitude <= hazardRadius then
								-- Teleport player to random location in arena
								local tAngle = rng:NextNumber(0, math.pi * 2)
								local tDist = rng:NextNumber(10, radius - 20)
								local newPos =
									Vector3.new(math.cos(tAngle) * tDist, root.Position.Y, math.sin(tAngle) * tDist)
								root.CFrame = CFrame.new(newPos) * (root.CFrame - root.CFrame.Position)
							end
						end
					end
				end
			end)
		end
	end
end

function ArenaService:_startHazardLoop()
	_hazardActive = true
	task.spawn(function()
		while _hazardActive do
			local stage = self:GetCurrentStage()
			local interval = stage.HazardInterval or 15
			task.wait(interval)
			if not _hazardActive then
				break
			end
			if GameService:GetState() == "Wave" then
				self:_spawnHazard()
			end
		end
	end)
end

function ArenaService:_stopHazardLoop()
	_hazardActive = false
end

function ArenaService:GetSpawnPositions(count: number): { Vector3 }
	local positions = {}
	local cfg = GameConfig.Enemies
	local rng = Random.new()
	local radius = GameConfig.Arena.Radius
	for _ = 1, count do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = cfg.SpawnDistance
		local x = math.cos(angle) * dist
		local z = math.sin(angle) * dist
		-- Clamp to circular arena
		local posDist = math.sqrt(x * x + z * z)
		if posDist > radius - 5 then
			local scale = (radius - 5) / posDist
			x *= scale
			z *= scale
		end
		table.insert(positions, Vector3.new(x, cfg.SpawnHeight, z))
	end
	return positions
end

function ArenaService:KnitInit()
	self:BuildArena()
end

function ArenaService:KnitStart()
	GameService = Knit.GetService("GameService")

	-- Stage transitions based on game elapsed time
	GameService.GameStateChanged:Connect(function(state: string)
		if state == "Wave" then
			-- Check for stage transition
			local elapsed = GameService:GetGameElapsed()
			local transitionTime = GameConfig.Stages.TransitionTime
			local stageCount = #GameConfig.Stages.List
			local newStage = math.min(math.floor(elapsed / transitionTime) + 1, stageCount)
			self:TransitionToStage(newStage)

			-- Start hazards if not already running
			if not _hazardActive then
				self:_startHazardLoop()
			end
		elseif state == "Lobby" or state == "WaitingForPlayers" then
			_currentStageIndex = 1
			self:_stopHazardLoop()
		elseif state == "GameOver" or state == "Victory" then
			self:_stopHazardLoop()
		end
	end)
end

return ArenaService
