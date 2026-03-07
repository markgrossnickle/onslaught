--!strict
--[=[
	@class EnemyAnimController
	Client-side enemy appendage animations.
	Animates tendrils, legs, wings, boss cores, and shell plates
	based on EnemyType StringValues and CollectionService tags.
]=]
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local PlatformUtil = require(ReplicatedStorage.Shared.PlatformUtil)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local EnemyAnimController = Knit.CreateController({
	Name = "EnemyAnimController",
})

local _enemyFolder: Folder? = nil
local _frameSkip = 0

-------------------------------------------------
-- ANIMATION HELPERS
-------------------------------------------------

local function animateDrone(model: Model, now: number)
	local body = model.PrimaryPart
	if not body then
		return
	end

	-- Tendril sway
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child.Name:sub(1, 7) == "Tendril" then
			local idx = child:GetAttribute("AppendageIndex") or 1
			local offset = idx * 0.7
			local swayAngle = math.sin(now * 2.5 + offset) * 15
			local weld = child:FindFirstChildOfClass("WeldConstraint")
			if weld then
				-- Tendrils swing by adjusting CFrame relative to body
				local baseLen = child.Size.Y
				local tendrilCount = 5
				local angle = (idx / tendrilCount) * math.pi * 2
				local radius = body.Size.X * 0.3
				local xOff = math.cos(angle) * radius
				local zOff = math.sin(angle) * radius
				child.CFrame = body.CFrame
					* CFrame.new(xOff, -body.Size.Y / 2 - baseLen / 2, zOff)
					* CFrame.Angles(math.rad(swayAngle), 0, math.rad(swayAngle * 0.5))
			end
		end
	end
end

local function animateSkitter(model: Model, now: number)
	local body = model.PrimaryPart
	if not body then
		return
	end

	-- Only animate legs when moving
	local velocity = body.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude

	if speed < 1 then
		return
	end

	local legCount = 6
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child.Name:sub(1, 3) == "Leg" then
			local idx = child:GetAttribute("AppendageIndex") or 1
			-- Alternating pair walk cycle
			local phase = ((idx - 1) % 2 == 0) and 0 or math.pi
			local cycle = math.sin(now * 8 + phase) * 20

			local side = (idx <= legCount / 2) and -1 or 1
			local legIdx = ((idx - 1) % (legCount / 2))
			local zOff = (legIdx / (legCount / 2 - 1) - 0.5) * body.Size.Z * 0.7

			child.CFrame = body.CFrame
				* CFrame.new(side * body.Size.X / 2, -body.Size.Y / 2, zOff)
				* CFrame.Angles(0, 0, side * math.rad(35))
				* CFrame.Angles(math.rad(cycle), 0, 0)
		end
	end
end

local function animateBehemoth(model: Model, now: number)
	local body = model.PrimaryPart
	if not body then
		return
	end

	local velocity = body.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude

	if speed < 0.5 then
		return
	end

	local legCount = 4
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child.Name:sub(1, 3) == "Leg" then
			local idx = child:GetAttribute("AppendageIndex") or 1
			-- Stomp cycle: slower, heavier
			local phase = ((idx - 1) % 2 == 0) and 0 or math.pi
			local cycle = math.sin(now * 4 + phase) * 12

			local side = (idx <= legCount / 2) and -1 or 1
			local legIdx = ((idx - 1) % (legCount / 2))
			local zOff = (legIdx == 0) and -body.Size.Z * 0.3 or body.Size.Z * 0.3

			child.CFrame = body.CFrame
				* CFrame.new(side * body.Size.X / 2, -body.Size.Y / 2, zOff)
				* CFrame.Angles(0, 0, side * math.rad(15))
				* CFrame.Angles(math.rad(cycle), 0, 0)
		end
	end
end

local function animateShade(model: Model, now: number)
	local body = model.PrimaryPart
	if not body then
		return
	end

	-- Wing flap
	local isDiving = false
	local typeVal = model:FindFirstChild("EnemyType") :: StringValue?
	if typeVal then
		-- Detect dive from velocity (moving downward quickly)
		local vy = body.AssemblyLinearVelocity.Y
		isDiving = vy < -5
	end

	local flapSpeed = isDiving and 12 or 6
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child.Name:sub(1, 4) == "Wing" then
			local idx = child:GetAttribute("AppendageIndex") or 1
			local side = (idx == 1) and -1 or 1
			local flapAngle = math.sin(now * flapSpeed) * math.rad(35)

			child.CFrame = body.CFrame
				* CFrame.new(side * (body.Size.X / 2 + 1.2), 0, 0)
				* CFrame.Angles(0, 0, side * flapAngle)
		end
	end
end

local function animateBoss(model: Model, now: number, isMega: boolean)
	local body = model.PrimaryPart
	if not body then
		return
	end

	-- Tendril flow
	local tendrilCount = isMega and 10 or 8
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child.Name:sub(1, 7) == "Tendril" then
			local idx = child:GetAttribute("AppendageIndex") or 1
			local offset = idx * 0.5
			local swayX = math.sin(now * 1.8 + offset) * 20
			local swayZ = math.cos(now * 1.3 + offset * 1.3) * 15

			local angle = (idx / tendrilCount) * math.pi * 2
			local r = body.Size.X * 0.35
			local len = child.Size.Y

			child.CFrame = body.CFrame
				* CFrame.new(math.cos(angle) * r, -body.Size.Y / 2 - len / 2, math.sin(angle) * r)
				* CFrame.Angles(math.rad(swayX), 0, math.rad(swayZ))
		end

		-- Core pulse (mega only)
		if isMega and child.Name == "Core" then
			local pulse = 0.85 + math.sin(now * 3) * 0.15
			local baseSize = body.Size * 0.3
			child.Size = baseSize * pulse
			-- Color pulse between white and magenta
			local t = (math.sin(now * 2) + 1) / 2
			child.Color = Color3.fromRGB(math.floor(255 - t * 55), math.floor(255 - t * 195), math.floor(255 - t * 55))
		end
	end
end

local function animateWorm(model: Model, now: number)
	local body = model.PrimaryPart
	if not body then
		return
	end

	-- Segment pulse: subtle size oscillation
	local core = model:FindFirstChild("Core") :: BasePart?
	if core then
		local pulse = 0.85 + math.sin(now * 4 + body.Position.X * 0.5) * 0.15
		local baseSize = body.Size * 0.35
		core.Size = baseSize * pulse
	end
end

local function animateLurker(model: Model, now: number)
	local body = model.PrimaryPart
	if not body then
		return
	end

	-- Ghostly pulse: body transparency oscillates
	body.Transparency = 0.4 + math.sin(now * 3) * 0.2

	-- Core pulse
	local core = model:FindFirstChild("Core") :: BasePart?
	if core then
		local pulse = 0.85 + math.sin(now * 5) * 0.15
		core.Size = body.Size * 0.4 * pulse
	end
end

local function animateCrystalback(model: Model, now: number)
	local body = model.PrimaryPart
	if not body then
		return
	end

	local velocity = body.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude

	-- Shell shimmer
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child.Name:sub(1, 5) == "Shell" then
			local idx = child:GetAttribute("AppendageIndex") or 1
			child.Transparency = 0.2 + math.sin(now * 2 + idx) * 0.1
		end

		-- Leg walk cycle
		if child:IsA("BasePart") and child.Name:sub(1, 3) == "Leg" and speed > 0.5 then
			local idx = child:GetAttribute("AppendageIndex") or 1
			local phase = ((idx - 1) % 2 == 0) and 0 or math.pi
			local cycle = math.sin(now * 5 + phase) * 10

			local side = (idx <= 2) and -1 or 1
			local zOff = ((idx - 1) % 2 == 0) and body.Size.Z * 0.25 or -body.Size.Z * 0.25

			child.CFrame = body.CFrame
				* CFrame.new(side * body.Size.X / 2, -body.Size.Y / 2 - 0.5, zOff)
				* CFrame.Angles(math.rad(cycle), 0, 0)
		end
	end
end

local function animateBroodmother(model: Model, now: number)
	local body = model.PrimaryPart
	if not body then
		return
	end

	-- Egg sac pulsing
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child.Name:sub(1, 6) == "EggSac" then
			local idx = child:GetAttribute("AppendageIndex") or 1
			local pulse = 0.9 + math.sin(now * 2 + idx * 1.5) * 0.15
			child.Size = Vector3.one * 1.2 * pulse
			child.Transparency = 0.2 + math.sin(now * 3 + idx) * 0.1
		end
	end
end

local function animateLeech(model: Model, now: number)
	local body = model.PrimaryPart
	if not body then
		return
	end

	-- Tail wiggle
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child.Name:sub(1, 4) == "Tail" then
			local idx = child:GetAttribute("AppendageIndex") or 1
			local wiggle = math.sin(now * 6 + idx * 2) * 15

			child.CFrame = body.CFrame
				* CFrame.new(0, 0, body.Size.Z / 2 + idx * body.Size.Z * 0.25)
				* CFrame.Angles(0, math.rad(wiggle * idx), 0)
		end
	end
end

local function animateHivemind(model: Model, now: number)
	local body = model.PrimaryPart
	if not body then
		return
	end

	-- Core pulse
	local core = model:FindFirstChild("Core") :: BasePart?
	if core then
		local pulse = 0.85 + math.sin(now * 3) * 0.15
		core.Size = body.Size * 0.4 * pulse
		local t = (math.sin(now * 2) + 1) / 2
		core.Color = Color3.fromRGB(255, math.floor(200 + t * 55), math.floor(60 + t * 40))
	end

	-- Rune orbiting
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child.Name:sub(1, 4) == "Rune" then
			local idx = child:GetAttribute("AppendageIndex") or 1
			local angle = now * 1.5 + (idx / 4) * math.pi * 2
			local r = body.Size.X * 0.6
			local yBob = math.sin(now * 3 + idx) * 0.5
			child.CFrame = body.CFrame * CFrame.new(math.cos(angle) * r, yBob, math.sin(angle) * r)
		end
	end
end

local function animateBurrower(model: Model, now: number)
	local body = model.PrimaryPart
	if not body then
		return
	end

	-- Ridge glow pulse
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child.Name:sub(1, 5) == "Ridge" then
			local idx = child:GetAttribute("AppendageIndex") or 1
			child.Transparency = 0.3 + math.sin(now * 4 + idx) * 0.2
		end
	end

	-- Drill rotation (spin the drill nose)
	local drill = model:FindFirstChild("Drill") :: BasePart?
	if drill then
		local speed = Vector3.new(body.AssemblyLinearVelocity.X, 0, body.AssemblyLinearVelocity.Z).Magnitude
		if speed > 1 then
			drill.CFrame = body.CFrame
				* CFrame.new(0, 0, -body.Size.Z / 2 - body.Size.X * 0.2)
				* CFrame.Angles(0, 0, now * 10)
		end
	end
end

local function animateVoidWraith(model: Model, now: number)
	local body = model.PrimaryPart
	if not body then
		return
	end

	-- Body flicker (transparency pulses)
	body.Transparency = 0.2 + math.sin(now * 4) * 0.15

	-- Core pulse
	local core = model:FindFirstChild("Core") :: BasePart?
	if core then
		local pulse = 0.85 + math.sin(now * 5) * 0.15
		core.Size = body.Size * 0.3 * pulse
	end

	-- Tendril sway
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child.Name:sub(1, 7) == "Tendril" then
			local idx = child:GetAttribute("AppendageIndex") or 1
			local swayAngle = math.sin(now * 2 + idx * 0.8) * 20
			local angle = (idx / 3) * math.pi * 2
			local r = body.Size.X * 0.25
			local len = child.Size.Y

			child.CFrame = body.CFrame
				* CFrame.new(math.cos(angle) * r, -body.Size.Y / 2 - len / 2, math.sin(angle) * r)
				* CFrame.Angles(math.rad(swayAngle), 0, math.rad(swayAngle * 0.5))
		end
	end
end

-------------------------------------------------
-- MAIN LOOP
-------------------------------------------------

function EnemyAnimController:KnitInit() end

function EnemyAnimController:KnitStart()
	local isMobile = PlatformUtil.IsMobile()
	local mobileFrameSkip = GameConfig.Mobile.AnimFrameSkip

	RunService.RenderStepped:Connect(function(_dt)
		_enemyFolder = workspace:FindFirstChild("Enemies") :: Folder?
		if not _enemyFolder then
			return
		end

		local children = _enemyFolder:GetChildren()
		local enemyCount = #children

		-- Performance: skip frames when lots of enemies
		_frameSkip += 1

		-- Mobile: always skip every other frame
		if isMobile and _frameSkip % mobileFrameSkip ~= 0 then
			return
		end

		if enemyCount > 100 and _frameSkip % 2 ~= 0 then
			return
		end
		if enemyCount > 150 and _frameSkip % 3 ~= 0 then
			return
		end

		local now = tick()

		for _, child in children do
			if not child:IsA("Model") then
				continue
			end

			local typeVal = child:FindFirstChild("EnemyType") :: StringValue?
			if not typeVal then
				continue
			end

			local enemyType = typeVal.Value

			if
				enemyType == "Drone"
				or enemyType == "Brute"
				or enemyType == "Dasher"
				or enemyType == "Swarmling"
				or enemyType == "Spitter"
			then
				animateDrone(child, now)
			elseif enemyType == "Skitter" then
				animateSkitter(child, now)
			elseif enemyType == "Behemoth" then
				animateBehemoth(child, now)
			elseif enemyType == "Shade" then
				animateShade(child, now)
			elseif
				enemyType == "Boss"
				or enemyType == "BroodQueen"
				or enemyType == "PhantomWeaver"
				or enemyType == "AbyssalSerpent"
				or enemyType == "VoidArchitect"
			then
				animateBoss(child, now, false)
			elseif enemyType == "MegaBoss" then
				animateBoss(child, now, true)
			elseif enemyType == "Worm" then
				animateWorm(child, now)
			elseif enemyType == "Lurker" then
				animateLurker(child, now)
			elseif enemyType == "Crystalback" then
				animateCrystalback(child, now)
			elseif enemyType == "Broodmother" then
				animateBroodmother(child, now)
			elseif enemyType == "Leech" then
				animateLeech(child, now)
			elseif enemyType == "Hivemind" then
				animateHivemind(child, now)
			elseif enemyType == "Burrower" then
				animateBurrower(child, now)
			elseif enemyType == "VoidWraith" then
				animateVoidWraith(child, now)
			end
		end
	end)
end

return EnemyAnimController
