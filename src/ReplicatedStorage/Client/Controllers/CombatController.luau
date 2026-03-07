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

local _cameraShakeOffset = Vector3.zero
local _cameraShakeTime = 0

function CombatController:_setupCamera()
	local camCfg = GameConfig.Camera
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = camCfg.FieldOfView

	RunService.RenderStepped:Connect(function(dt)
		local char = Player.Character
		if not char then
			return
		end
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end

		-- Screen shake decay
		if _cameraShakeTime > 0 then
			_cameraShakeTime -= dt
			local intensity = math.clamp(_cameraShakeTime, 0, 1) * 1.5
			_cameraShakeOffset = Vector3.new(
				(math.random() - 0.5) * 2 * intensity,
				(math.random() - 0.5) * 2 * intensity,
				(math.random() - 0.5) * 2 * intensity
			)
		else
			_cameraShakeOffset = Vector3.zero
		end

		local angleRad = math.rad(camCfg.Angle)
		local offset = Vector3.new(0, math.sin(angleRad) * camCfg.Distance, math.cos(angleRad) * camCfg.Distance)
		local targetPos = root.Position
		camera.CFrame = CFrame.lookAt(targetPos + offset + _cameraShakeOffset, targetPos)
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

		-- Punch scale: start at 1.3x, shrink to 1x over 0.1s
		local punchDuration = 0.1

		while elapsed < lifetime do
			local dt = RunService.RenderStepped:Wait()
			elapsed += dt
			attachment.Position += Vector3.new(0, speed * dt * (1 - elapsed / lifetime), 0)
			label.TextTransparency = elapsed / lifetime
			label.TextStrokeTransparency = 0.5 + (elapsed / lifetime) * 0.5

			-- Punch scale
			if elapsed < punchDuration then
				local scale = 1.3 - 0.3 * (elapsed / punchDuration)
				billboard.Size = UDim2.new(0, math.floor(100 * scale), 0, math.floor(40 * scale))
			end
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
	-- White flash at death position
	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.one * 3
	flash.Color = Color3.fromRGB(255, 255, 255)
	flash.Material = Enum.Material.Neon
	flash.Anchored = true
	flash.CanCollide = false
	flash.CastShadow = false
	flash.Transparency = 0.2
	flash.Position = position
	flash.Parent = workspace

	TweenService:Create(flash, TweenInfo.new(0.2), { Transparency = 1, Size = Vector3.one * 6 }):Play()
	task.delay(0.2, function()
		flash:Destroy()
	end)

	-- Colored parts burst (8-12 pieces)
	local count = math.random(8, 12)
	for _ = 1, count do
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
-- PROJECTILE IMPACT VFX
-------------------------------------------------

function CombatController:_playProjectileImpact(position: Vector3)
	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.one * 1.5
	flash.Color = GameConfig.Weapons.Projectile.Color
	flash.Material = Enum.Material.Neon
	flash.Anchored = true
	flash.CanCollide = false
	flash.CastShadow = false
	flash.Transparency = 0.2
	flash.Position = position
	flash.Parent = workspace

	TweenService:Create(flash, TweenInfo.new(0.15), { Size = Vector3.one * 4, Transparency = 1 }):Play()
	task.delay(0.15, function()
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

	-- Flicker effect: toggle transparency rapidly
	task.spawn(function()
		local elapsed = 0
		while elapsed < lightCfg.BeamDuration do
			local dt = RunService.RenderStepped:Wait()
			elapsed += dt
			-- Flicker between 0 and 0.3
			beam.Transparency = (math.floor(elapsed * 30) % 2 == 0) and 0 or 0.3
		end
		TweenService:Create(beam, TweenInfo.new(0.1), { Transparency = 1 }):Play()
		task.delay(0.1, function()
			beam:Destroy()
		end)
	end)
end

function CombatController:_playLightningSpark(position: Vector3)
	-- Small spark burst at chain target positions
	for _ = 1, 4 do
		local spark = Instance.new("Part")
		spark.Size = Vector3.one * 0.3
		spark.Color = GameConfig.Weapons.Lightning.BeamColor
		spark.Material = Enum.Material.Neon
		spark.Anchored = false
		spark.CanCollide = false
		spark.CastShadow = false
		spark.Position = position
		spark.Parent = workspace

		spark:ApplyImpulse(Vector3.new((math.random() - 0.5) * 20, math.random() * 15 + 5, (math.random() - 0.5) * 20))

		task.delay(0.3, function()
			if spark and spark.Parent then
				spark:Destroy()
			end
		end)
	end
end

-------------------------------------------------
-- XP GEM BOB + SPARKLE
-------------------------------------------------

function CombatController:_setupGemEffects()
	-- Bob gems up/down and add sparkle emitters
	RunService.RenderStepped:Connect(function(_dt)
		local gemFolder = workspace:FindFirstChild("XPGems")
		if not gemFolder then
			return
		end

		local now = tick()
		for _, child in gemFolder:GetChildren() do
			if child:IsA("BasePart") and child.Name == "XPGem" then
				-- Bob: sine wave, 0.5 stud amplitude
				local baseY = child:GetAttribute("BaseY")
				if not baseY then
					child:SetAttribute("BaseY", child.Position.Y)
					baseY = child.Position.Y

					-- Add sparkle ParticleEmitter on first encounter
					local emitter = Instance.new("ParticleEmitter")
					emitter.Name = "Sparkle"
					emitter.Color = ColorSequence.new(GameConfig.XPGems.GlowColor)
					emitter.Size = NumberSequence.new(0.2, 0)
					emitter.Lifetime = NumberRange.new(0.3, 0.6)
					emitter.Rate = 8
					emitter.Speed = NumberRange.new(1, 3)
					emitter.SpreadAngle = Vector2.new(180, 180)
					emitter.LightEmission = 1
					emitter.Parent = child
				end

				local bobOffset = math.sin(now * 3 + (child.Position.X + child.Position.Z) * 0.5) * 0.5
				child.Position = Vector3.new(child.Position.X, baseY + bobOffset, child.Position.Z)
			end
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

	-- Expanding ring
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

	-- "LEVEL UP!" text with punch scale
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

	-- White edge flash (fullscreen)
	local PlayerGui = Player:WaitForChild("PlayerGui")
	local hudGui = PlayerGui:FindFirstChild("OnslaughtHUD") :: ScreenGui?
	if hudGui then
		local edgeFlash = Instance.new("Frame")
		edgeFlash.Size = UDim2.new(1, 0, 1, 0)
		edgeFlash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		edgeFlash.BackgroundTransparency = 0.85
		edgeFlash.BorderSizePixel = 0
		edgeFlash.ZIndex = 90
		edgeFlash.Parent = hudGui

		TweenService:Create(edgeFlash, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		task.delay(0.4, function()
			edgeFlash:Destroy()
		end)
	end

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

			-- Punch scale text: 1.5x -> 1x in first 0.15s
			if elapsed < 0.15 then
				local scale = 1.5 - 0.5 * (elapsed / 0.15)
				billboard.Size = UDim2.new(0, math.floor(200 * scale), 0, math.floor(60 * scale))
			end

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
-- BOSS SPAWN VFX
-------------------------------------------------

function CombatController:_playBossSpawnWarning()
	-- Screen shake
	_cameraShakeTime = 0.8

	-- "BOSS INCOMING" text
	local PlayerGui = Player:WaitForChild("PlayerGui")
	local hudGui = PlayerGui:FindFirstChild("OnslaughtHUD") :: ScreenGui?
	if not hudGui then
		return
	end

	local warning = Instance.new("TextLabel")
	warning.Name = "BossWarning"
	warning.Size = UDim2.new(1, 0, 0, 80)
	warning.Position = UDim2.new(0, 0, 0.35, 0)
	warning.BackgroundTransparency = 1
	warning.Text = "BOSS INCOMING"
	warning.TextColor3 = Color3.fromRGB(255, 60, 60)
	warning.Font = Enum.Font.GothamBlack
	warning.TextSize = 48
	warning.TextStrokeTransparency = 0.3
	warning.TextStrokeColor3 = Color3.fromRGB(80, 0, 0)
	warning.ZIndex = 95
	warning.Parent = hudGui

	task.spawn(function()
		local elapsed = 0
		local duration = 2.0
		while elapsed < duration do
			local dt = RunService.RenderStepped:Wait()
			elapsed += dt
			-- Pulse the text size
			local pulse = math.sin(elapsed * 8) * 0.1
			warning.TextSize = math.floor(48 * (1 + pulse))
			-- Fade out in last 0.5s
			if elapsed > duration - 0.5 then
				warning.TextTransparency = (elapsed - (duration - 0.5)) * 2
				warning.TextStrokeTransparency = 0.3 + (elapsed - (duration - 0.5)) * 1.4
			end
		end
		warning:Destroy()
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

	-- XP gem bob + sparkle
	self:_setupGemEffects()

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

	-- Projectile impact VFX
	CombatService.ProjectileImpact:Connect(function(position: Vector3)
		self:_playProjectileImpact(position)
	end)

	-- Lightning beam VFX with spark bursts
	CombatService.LightningFired:Connect(function(startPos: Vector3, _targetPos: Vector3, chainPositions: { Vector3 })
		local prevPos = startPos
		for _, chainPos in chainPositions do
			self:_playLightningBeam(prevPos, chainPos)
			self:_playLightningSpark(chainPos)
			prevPos = chainPos
		end
	end)

	-- Boss spawn warning
	CombatService.BossSpawned:Connect(function()
		self:_playBossSpawnWarning()
	end)

	-- Level up VFX
	GameService.ShowUpgradeCards:Connect(function(_cards: any)
		self:_playLevelUpEffect()
	end)
end

return CombatController
