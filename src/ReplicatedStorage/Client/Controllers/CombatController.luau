--!strict
--[=[
	Client-side VFX for auto-attack weapons + isometric camera.
	No manual attack input — all combat is automatic.
]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local Player = Players.LocalPlayer

local CombatController = Knit.CreateController({
	Name = "CombatController",
})

-------------------------------------------------
-- ISOMETRIC CAMERA
-------------------------------------------------

function CombatController:_setupCamera()
	local camCfg = GameConfig.Camera
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = camCfg.FieldOfView

	RunService.RenderStepped:Connect(function(_dt)
		local char = Player.Character
		if not char then
			return
		end
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end

		local angleRad = math.rad(camCfg.Angle)
		local offset = Vector3.new(0, math.sin(angleRad) * camCfg.Distance, math.cos(angleRad) * camCfg.Distance)
		local targetPos = root.Position
		camera.CFrame = CFrame.lookAt(targetPos + offset, targetPos)
	end)
end

-------------------------------------------------
-- VFX (damage numbers, hit flash, death particles)
-------------------------------------------------

function CombatController:_showDamageNumber(position: Vector3, damage: number)
	local cfg = GameConfig.VFX

	local attachment = Instance.new("Part")
	attachment.Size = Vector3.new(0.1, 0.1, 0.1)
	attachment.Position = position + Vector3.new((math.random() - 0.5) * 2, 2, (math.random() - 0.5) * 2)
	attachment.Anchored = true
	attachment.CanCollide = false
	attachment.Transparency = 1
	attachment.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 100, 0, 40)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = attachment

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = tostring(damage)
	label.TextColor3 = Color3.fromRGB(255, 80, 80)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 24
	label.TextStrokeTransparency = 0.5
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.Parent = billboard

	task.spawn(function()
		local elapsed = 0
		local lifetime = cfg.DamageNumberLifetime
		local speed = cfg.DamageNumberRiseSpeed

		while elapsed < lifetime do
			local dt = RunService.RenderStepped:Wait()
			elapsed += dt
			attachment.Position += Vector3.new(0, speed * dt * (1 - elapsed / lifetime), 0)
			label.TextTransparency = elapsed / lifetime
			label.TextStrokeTransparency = 0.5 + (elapsed / lifetime) * 0.5
		end

		attachment:Destroy()
	end)
end

function CombatController:_flashEnemy(model: Model)
	if not model or not model.Parent then
		return
	end

	local cfg = GameConfig.VFX
	local body = model:FindFirstChild("Body") :: BasePart?
	if not body then
		return
	end

	local origColor = body.Color
	body.Color = cfg.HitFlashColor
	task.delay(cfg.HitFlashDuration, function()
		if body and body.Parent then
			body.Color = origColor
		end
	end)
end

function CombatController:_playDeathEffect(position: Vector3, color: Color3)
	local cfg = GameConfig.VFX

	for _ = 1, cfg.DeathParticleCount do
		local part = Instance.new("Part")
		part.Size = Vector3.new(math.random() * 1.5 + 0.3, math.random() * 1.5 + 0.3, math.random() * 1.5 + 0.3)
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.Position = position + Vector3.new((math.random() - 0.5) * 3, math.random() * 2, (math.random() - 0.5) * 3)
		part.Anchored = false
		part.CanCollide = true
		part.Parent = workspace

		part:ApplyImpulse(Vector3.new((math.random() - 0.5) * 80, math.random() * 60 + 20, (math.random() - 0.5) * 80))

		task.delay(1.5, function()
			if part and part.Parent then
				TweenService:Create(part, TweenInfo.new(0.5), { Transparency = 1 }):Play()
				task.delay(0.5, function()
					part:Destroy()
				end)
			end
		end)
	end
end

function CombatController:_playGemCollectEffect()
	local char = Player.Character
	if not char then
		return
	end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.one * 4
	flash.Color = GameConfig.XPGems.GlowColor
	flash.Material = Enum.Material.Neon
	flash.Anchored = true
	flash.CanCollide = false
	flash.CastShadow = false
	flash.Transparency = 0.5
	flash.Position = root.Position
	flash.Parent = workspace

	task.spawn(function()
		local elapsed = 0
		while elapsed < 0.25 do
			local dt = RunService.RenderStepped:Wait()
			elapsed += dt
			flash.Transparency = 0.5 + (elapsed / 0.25) * 0.5
			flash.Size = Vector3.one * (4 + elapsed * 12)
		end
		flash:Destroy()
	end)
end

-------------------------------------------------
-- LIGHTNING VFX
-------------------------------------------------

function CombatController:_playLightningBeam(startPos: Vector3, endPos: Vector3)
	local lightCfg = GameConfig.Weapons.Lightning

	local dist = (endPos - startPos).Magnitude
	local midPoint = (startPos + endPos) / 2

	local beam = Instance.new("Part")
	beam.Name = "LightningBeam"
	beam.Size = Vector3.new(0.4, 0.4, dist)
	beam.Color = lightCfg.BeamColor
	beam.Material = Enum.Material.Neon
	beam.Anchored = true
	beam.CanCollide = false
	beam.CastShadow = false
	beam.CFrame = CFrame.lookAt(midPoint, endPos)
	beam.Parent = workspace

	task.delay(lightCfg.BeamDuration, function()
		if beam and beam.Parent then
			TweenService:Create(beam, TweenInfo.new(0.1), { Transparency = 1 }):Play()
			task.delay(0.1, function()
				beam:Destroy()
			end)
		end
	end)
end

-------------------------------------------------
-- LEVEL UP VFX
-------------------------------------------------

function CombatController:_playLevelUpEffect()
	local char = Player.Character
	if not char then
		return
	end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	-- Flash ring
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.5, 8, 8)
	ring.Color = Color3.fromRGB(255, 220, 50)
	ring.Material = Enum.Material.Neon
	ring.Anchored = true
	ring.CanCollide = false
	ring.CastShadow = false
	ring.Transparency = 0.3
	ring.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace

	-- "LEVEL UP!" text
	local textPart = Instance.new("Part")
	textPart.Size = Vector3.new(0.1, 0.1, 0.1)
	textPart.Position = root.Position + Vector3.new(0, 5, 0)
	textPart.Anchored = true
	textPart.CanCollide = false
	textPart.Transparency = 1
	textPart.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 200, 0, 60)
	billboard.AlwaysOnTop = true
	billboard.Parent = textPart

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "LEVEL UP!"
	label.TextColor3 = Color3.fromRGB(255, 220, 50)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 36
	label.TextStrokeTransparency = 0.3
	label.TextStrokeColor3 = Color3.fromRGB(100, 80, 0)
	label.Parent = billboard

	task.spawn(function()
		local elapsed = 0
		local duration = 1.5
		while elapsed < duration do
			local dt = RunService.RenderStepped:Wait()
			elapsed += dt
			local t = elapsed / duration

			-- Expand ring
			local ringSize = 8 + t * 20
			ring.Size = Vector3.new(0.5, ringSize, ringSize)
			ring.Transparency = 0.3 + t * 0.7

			-- Float text up and fade
			textPart.Position += Vector3.new(0, dt * 15, 0)
			if t > 0.5 then
				label.TextTransparency = (t - 0.5) * 2
				label.TextStrokeTransparency = 0.3 + (t - 0.5) * 1.4
			end
		end

		ring:Destroy()
		textPart:Destroy()
	end)
end

-------------------------------------------------
-- LIFECYCLE
-------------------------------------------------

function CombatController:KnitInit() end

function CombatController:KnitStart()
	local EnemyService = Knit.GetService("EnemyService")
	local GameService = Knit.GetService("GameService")
	local CombatService = Knit.GetService("CombatService")

	-- Isometric camera
	self:_setupCamera()

	-- Enemy hit VFX
	EnemyService.EnemyDamaged:Connect(function(model: Model, damage: number, position: Vector3)
		self:_showDamageNumber(position, damage)
		self:_flashEnemy(model)
	end)

	-- Enemy death VFX
	EnemyService.EnemyKilled:Connect(function(model: Model, _enemyType: string)
		if model and model.PrimaryPart then
			self:_playDeathEffect(model.PrimaryPart.Position, model.PrimaryPart.Color)
		end
	end)

	-- XP gem collect VFX
	GameService.XPGemCollected:Connect(function(_amount: number)
		self:_playGemCollectEffect()
	end)

	-- Lightning beam VFX
	CombatService.LightningFired:Connect(function(startPos: Vector3, _targetPos: Vector3, chainPositions: { Vector3 })
		local prevPos = startPos
		for _, chainPos in chainPositions do
			self:_playLightningBeam(prevPos, chainPos)
			prevPos = chainPos
		end
	end)

	-- Level up VFX
	GameService.ShowUpgradeCards:Connect(function(_cards: any)
		self:_playLevelUpEffect()
	end)
end

return CombatController
