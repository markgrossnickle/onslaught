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

function CombatController:_playDeathEffect(position: Vector3, enemyType: string)
	local vfxCfg = GameConfig.VFX

	-- Void flash at death position (purple/dark burst)
	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.one * 3
	flash.Color = vfxCfg.VoidDeathColor1
	flash.Material = Enum.Material.Neon
	flash.Anchored = true
	flash.CanCollide = false
	flash.CastShadow = false
	flash.Transparency = 0.2
	flash.Position = position
	flash.Parent = workspace

	TweenService:Create(flash, TweenInfo.new(0.25), { Transparency = 1, Size = Vector3.one * 7 }):Play()
	task.delay(0.25, function()
		flash:Destroy()
	end)

	-- Core color flash (white->purple)
	local coreFlash = Instance.new("Part")
	coreFlash.Shape = Enum.PartType.Ball
	coreFlash.Size = Vector3.one * 1.5
	coreFlash.Color = Color3.fromRGB(255, 255, 255)
	coreFlash.Material = Enum.Material.Neon
	coreFlash.Anchored = true
	coreFlash.CanCollide = false
	coreFlash.CastShadow = false
	coreFlash.Transparency = 0
	coreFlash.Position = position
	coreFlash.Parent = workspace

	TweenService:Create(coreFlash, TweenInfo.new(0.15), { Color = vfxCfg.VoidDeathColor1, Transparency = 1 }):Play()
	task.delay(0.15, function()
		coreFlash:Destroy()
	end)

	-- Void particle burst (dark purple/black pieces)
	local count = math.random(6, 10)
	local colors = { vfxCfg.VoidDeathColor1, vfxCfg.VoidDeathColor2 }

	-- Shade: wings fold death (just smaller burst)
	if enemyType == "Shade" then
		count = 4
	end

	for i = 1, count do
		local part = Instance.new("Part")
		part.Size = Vector3.new(math.random() * 1.2 + 0.2, math.random() * 1.2 + 0.2, math.random() * 1.2 + 0.2)
		part.Color = colors[(i % 2) + 1]
		part.Material = Enum.Material.SmoothPlastic
		part.Position = position
			+ Vector3.new((math.random() - 0.5) * 2, math.random() * 1.5, (math.random() - 0.5) * 2)
		part.Anchored = false
		part.CanCollide = true
		part.Parent = workspace

		part:ApplyImpulse(Vector3.new((math.random() - 0.5) * 60, math.random() * 40 + 15, (math.random() - 0.5) * 60))

		task.delay(1.2, function()
			if part and part.Parent then
				TweenService:Create(part, TweenInfo.new(0.4), { Transparency = 1 }):Play()
				task.delay(0.4, function()
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
-- BOSS ATTACK VFX
-------------------------------------------------

function CombatController:_playTendrilSlam(position: Vector3, radius: number)
	_cameraShakeTime = 0.4

	-- Telegraph: red ring on ground
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, radius * 2, radius * 2)
	ring.Color = Color3.fromRGB(255, 40, 40)
	ring.Material = Enum.Material.Neon
	ring.Anchored = true
	ring.CanCollide = false
	ring.CastShadow = false
	ring.Transparency = 0.5
	ring.CFrame = CFrame.new(position.X, 0.5, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace

	-- Shockwave expand
	task.spawn(function()
		local elapsed = 0
		while elapsed < 0.5 do
			local dt = RunService.RenderStepped:Wait()
			elapsed += dt
			local t = elapsed / 0.5
			ring.Transparency = 0.5 + t * 0.5
			local expandSize = radius * 2 + t * 10
			ring.Size = Vector3.new(0.3, expandSize, expandSize)
		end
		ring:Destroy()
	end)
end

function CombatController:_playVoidPull(position: Vector3, duration: number)
	_cameraShakeTime = duration * 0.3

	-- Dark vortex sphere
	local vortex = Instance.new("Part")
	vortex.Shape = Enum.PartType.Ball
	vortex.Size = Vector3.one * 6
	vortex.Color = Color3.fromRGB(30, 0, 50)
	vortex.Material = Enum.Material.ForceField
	vortex.Anchored = true
	vortex.CanCollide = false
	vortex.CastShadow = false
	vortex.Transparency = 0.4
	vortex.Position = position
	vortex.Parent = workspace

	task.spawn(function()
		local elapsed = 0
		while elapsed < duration do
			local dt = RunService.RenderStepped:Wait()
			elapsed += dt
			local pulse = math.sin(elapsed * 6) * 2
			vortex.Size = Vector3.one * (6 + pulse)
			vortex.Transparency = 0.4 + math.sin(elapsed * 4) * 0.1
		end
		TweenService:Create(vortex, TweenInfo.new(0.3), { Transparency = 1, Size = Vector3.one * 2 }):Play()
		task.delay(0.3, function()
			vortex:Destroy()
		end)
	end)
end

-------------------------------------------------
-- POWER-UP VFX
-------------------------------------------------

function CombatController:_playPowerUpCollect(puType: string, puName: string)
	local char = Player.Character
	if not char then
		return
	end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local puCfg = (GameConfig.PowerUps.Types :: any)[puType]
	local color = puCfg and puCfg.Color or Color3.fromRGB(255, 255, 255)

	-- Flash
	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.one * 5
	flash.Color = color
	flash.Material = Enum.Material.Neon
	flash.Anchored = true
	flash.CanCollide = false
	flash.CastShadow = false
	flash.Transparency = 0.3
	flash.Position = root.Position
	flash.Parent = workspace

	TweenService:Create(flash, TweenInfo.new(0.3), { Transparency = 1, Size = Vector3.one * 8 }):Play()
	task.delay(0.3, function()
		flash:Destroy()
	end)

	-- Floating text
	local textPart = Instance.new("Part")
	textPart.Size = Vector3.new(0.1, 0.1, 0.1)
	textPart.Position = root.Position + Vector3.new(0, 4, 0)
	textPart.Anchored = true
	textPart.CanCollide = false
	textPart.Transparency = 1
	textPart.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 200, 0, 40)
	billboard.AlwaysOnTop = true
	billboard.Parent = textPart

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = puName
	label.TextColor3 = color
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 22
	label.TextStrokeTransparency = 0.3
	label.Parent = billboard

	task.spawn(function()
		local elapsed = 0
		while elapsed < 1.5 do
			local dt = RunService.RenderStepped:Wait()
			elapsed += dt
			textPart.Position += Vector3.new(0, dt * 12, 0)
			if elapsed > 0.8 then
				label.TextTransparency = (elapsed - 0.8) / 0.7
				label.TextStrokeTransparency = 0.3 + (elapsed - 0.8)
			end
		end
		textPart:Destroy()
	end)
end

function CombatController:_playVoidBombExplosion(position: Vector3)
	_cameraShakeTime = 0.5

	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Ball
	ring.Size = Vector3.one * 5
	ring.Color = Color3.fromRGB(200, 30, 30)
	ring.Material = Enum.Material.Neon
	ring.Anchored = true
	ring.CanCollide = false
	ring.CastShadow = false
	ring.Transparency = 0.2
	ring.Position = position
	ring.Parent = workspace

	TweenService:Create(ring, TweenInfo.new(0.4), { Size = Vector3.one * 60, Transparency = 1 }):Play()
	task.delay(0.4, function()
		ring:Destroy()
	end)
end

local _shieldBubble: BasePart? = nil

function CombatController:_showShieldBubble()
	if _shieldBubble then
		return
	end

	local char = Player.Character
	if not char then
		return
	end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local bubble = Instance.new("Part")
	bubble.Name = "ShieldBubble"
	bubble.Shape = Enum.PartType.Ball
	bubble.Size = Vector3.one * 8
	bubble.Color = Color3.fromRGB(80, 220, 255)
	bubble.Material = Enum.Material.ForceField
	bubble.Transparency = 0.7
	bubble.Anchored = false
	bubble.CanCollide = false
	bubble.CastShadow = false
	bubble.Parent = workspace

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = bubble
	weld.Parent = bubble
	bubble.CFrame = root.CFrame

	_shieldBubble = bubble
end

function CombatController:_removeShieldBubble()
	if _shieldBubble then
		-- Shatter effect
		local pos = _shieldBubble.Position
		_shieldBubble:Destroy()
		_shieldBubble = nil

		for _ = 1, 6 do
			local shard = Instance.new("Part")
			shard.Size = Vector3.new(0.5, 0.5, 0.1)
			shard.Color = Color3.fromRGB(80, 220, 255)
			shard.Material = Enum.Material.Neon
			shard.Anchored = false
			shard.CanCollide = false
			shard.CastShadow = false
			shard.Position = pos + Vector3.new((math.random() - 0.5) * 3, math.random() * 2, (math.random() - 0.5) * 3)
			shard.Parent = workspace
			shard:ApplyImpulse(
				Vector3.new((math.random() - 0.5) * 40, math.random() * 20 + 10, (math.random() - 0.5) * 40)
			)
			task.delay(0.5, function()
				if shard.Parent then
					shard:Destroy()
				end
			end)
		end
	end
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

	-- Enemy death VFX (void-themed)
	EnemyService.EnemyKilled:Connect(function(model: Model, enemyType: string)
		if model and model.PrimaryPart then
			self:_playDeathEffect(model.PrimaryPart.Position, enemyType)
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

	-- Boss attack VFX
	EnemyService.TendrilSlam:Connect(function(position: Vector3, radius: number)
		self:_playTendrilSlam(position, radius)
	end)

	EnemyService.VoidPullStarted:Connect(function(position: Vector3, duration: number)
		self:_playVoidPull(position, duration)
	end)

	-- Power-up VFX
	local PowerUpService = Knit.GetService("PowerUpService")

	PowerUpService.PowerUpCollected:Connect(function(puType: string, puName: string)
		self:_playPowerUpCollect(puType, puName)
	end)

	PowerUpService.VoidBombExploded:Connect(function(position: Vector3)
		self:_playVoidBombExplosion(position)
	end)

	PowerUpService.BuffStarted:Connect(function(puType: string, _duration: number)
		if puType == "VoidShield" then
			self:_showShieldBubble()
		end
	end)

	PowerUpService.BuffEnded:Connect(function(puType: string)
		if puType == "VoidShield" then
			self:_removeShieldBubble()
		end
	end)
end

return CombatController
