--!strict
--[=[
	Client-side VFX for auto-attack weapons + isometric camera.
	No manual attack input — all combat is automatic.
]=]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
				game:GetService("TweenService"):Create(part, TweenInfo.new(0.5), { Transparency = 1 }):Play()
				task.delay(0.5, function()
					part:Destroy()
				end)
			end
		end)
	end
end

function CombatController:_playGemCollectEffect()
	-- Brief green flash around player
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
-- LIFECYCLE
-------------------------------------------------

function CombatController:KnitInit() end

function CombatController:KnitStart()
	local EnemyService = Knit.GetService("EnemyService")
	local GameService = Knit.GetService("GameService")

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
end

return CombatController
