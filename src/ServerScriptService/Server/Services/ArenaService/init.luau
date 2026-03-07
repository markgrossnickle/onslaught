--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local ArenaService = Knit.CreateService({
	Name = "ArenaService",
	Client = {},
})

local ArenaFolder: Folder = nil :: any

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
	local halfFloor = cfg.FloorSize / 2

	-- Floor
	self:_createPart("Floor", cfg.FloorSize, cfg.FloorPosition, cfg.FloorColor)

	-- Walls (N, S, E, W)
	local wallH = cfg.WallHeight
	local wallT = cfg.WallThickness
	local floorX = cfg.FloorSize.X
	local floorZ = cfg.FloorSize.Z
	local wallY = wallH / 2

	-- North wall (+Z)
	self:_createPart(
		"WallNorth",
		Vector3.new(floorX + wallT * 2, wallH, wallT),
		Vector3.new(0, wallY, halfFloor.Z + wallT / 2),
		cfg.WallColor
	)
	-- South wall (-Z)
	self:_createPart(
		"WallSouth",
		Vector3.new(floorX + wallT * 2, wallH, wallT),
		Vector3.new(0, wallY, -halfFloor.Z - wallT / 2),
		cfg.WallColor
	)
	-- East wall (+X)
	self:_createPart(
		"WallEast",
		Vector3.new(wallT, wallH, floorZ),
		Vector3.new(halfFloor.X + wallT / 2, wallY, 0),
		cfg.WallColor
	)
	-- West wall (-X)
	self:_createPart(
		"WallWest",
		Vector3.new(wallT, wallH, floorZ),
		Vector3.new(-halfFloor.X - wallT / 2, wallY, 0),
		cfg.WallColor
	)

	-- Obstacles
	self:_spawnObstacles()

	-- Lighting
	self:_setupLighting()
end

function ArenaService:_spawnObstacles()
	local cfg = GameConfig.Arena
	local halfFloor = cfg.FloorSize.X / 2
	local rng = Random.new()

	for i = 1, cfg.ObstacleCount do
		local sizeX = rng:NextNumber(cfg.ObstacleMinSize.X, cfg.ObstacleMaxSize.X)
		local sizeY = rng:NextNumber(cfg.ObstacleMinSize.Y, cfg.ObstacleMaxSize.Y)
		local sizeZ = rng:NextNumber(cfg.ObstacleMinSize.Z, cfg.ObstacleMaxSize.Z)

		local margin = cfg.ObstacleSpawnMargin
		local range = halfFloor - margin - sizeX / 2
		local x = rng:NextNumber(-range, range)
		local z = rng:NextNumber(-range, range)

		-- Keep obstacles away from center spawn
		if math.abs(x) < margin and math.abs(z) < margin then
			x = x + (if x >= 0 then margin else -margin)
		end

		self:_createPart(
			"Obstacle" .. i,
			Vector3.new(sizeX, sizeY, sizeZ),
			Vector3.new(x, sizeY / 2, z),
			cfg.ObstacleColor
		)
	end
end

function ArenaService:_setupLighting()
	local lighting = game:GetService("Lighting")
	lighting.Ambient = Color3.fromRGB(40, 40, 50)
	lighting.OutdoorAmbient = Color3.fromRGB(60, 60, 70)
	lighting.Brightness = 1.5
	lighting.ClockTime = 0 -- Night time for atmosphere
	lighting.FogEnd = 500
	lighting.FogColor = Color3.fromRGB(15, 15, 20)
end

function ArenaService:GetArenaFolder(): Folder
	return ArenaFolder
end

function ArenaService:GetSpawnPositions(count: number): { Vector3 }
	local positions = {}
	local cfg = GameConfig.Enemies
	local rng = Random.new()
	for _ = 1, count do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = cfg.SpawnDistance
		local x = math.cos(angle) * dist
		local z = math.sin(angle) * dist
		-- Clamp to arena bounds
		local halfFloor = GameConfig.Arena.FloorSize.X / 2 - 5
		x = math.clamp(x, -halfFloor, halfFloor)
		z = math.clamp(z, -halfFloor, halfFloor)
		table.insert(positions, Vector3.new(x, cfg.SpawnHeight, z))
	end
	return positions
end

function ArenaService:KnitInit()
	self:BuildArena()
end

function ArenaService:KnitStart() end

return ArenaService
