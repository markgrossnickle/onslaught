--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local Player = Players.LocalPlayer

local CombatController = Knit.CreateController({
	Name = "CombatController",
})

local _lastAttackTime: number = 0
local _cooldownUI: Frame? = nil

function CombatController:_createSwordVisual()
	-- Create a simple sword tool visual attached to character
	local function setupCharacter(character: Model)
		task.defer(function()
			local rightArm = character:WaitForChild("Right Arm", 5) or character:WaitForChild("RightHand", 5)
			if not rightArm then
				return
			end

			local sword = Instance.new("Part")
			sword.Name = "SwordVisual"
			sword.Size = Vector3.new(0.4, 4, 0.4)
			sword.Color = Color3.fromRGB(180, 180, 200)
			sword.Material = Enum.Material.Metal
			sword.CanCollide = false
			sword.Massless = true
			sword.Anchored = false

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = rightArm :: BasePart
			weld.Part1 = sword
			weld.Parent = sword

			sword.CFrame = (rightArm :: BasePart).CFrame * CFrame.new(0, -2.5, 0)
			sword.Parent = character
		end)
	end

	if Player.Character then
		setupCharacter(Player.Character)
	end
	Player.CharacterAdded:Connect(setupCharacter)
end

function CombatController:_attack()
	local now = tick()
	local weapon = GameConfig.Weapons.Sword

	if (now - _lastAttackTime) < weapon.SwingCooldown then
		return
	end
	_lastAttackTime = now

	-- Fire to server
	local CombatService = Knit.GetService("CombatService")
	CombatService:Attack()

	-- Swing animation (simple camera shake + visual)
	self:_playSwingEffect()
end

function CombatController:_playSwingEffect()
	local char = Player.Character
	if not char then
		return
	end
	local sword = char:FindFirstChild("SwordVisual") :: BasePart?
	if not sword then
		return
	end

	-- Brief color flash on the sword
	local origColor = sword.Color
	sword.Color = Color3.fromRGB(255, 255, 255)
	task.delay(0.1, function()
		if sword and sword.Parent then
			sword.Color = origColor
		end
	end)

	-- Camera shake
	local camera = workspace.CurrentCamera
	if camera then
		task.spawn(function()
			local intensity = 0.3
			for _ = 1, 3 do
				local offset =
					CFrame.Angles((math.random() - 0.5) * intensity * 0.02, (math.random() - 0.5) * intensity * 0.02, 0)
				camera.CFrame = camera.CFrame * offset
				RunService.RenderStepped:Wait()
			end
		end)
	end
end

function CombatController:KnitInit() end

function CombatController:KnitStart()
	local CombatService = Knit.GetService("CombatService")
	local EnemyService = Knit.GetService("EnemyService")

	-- Mouse click / tap to attack
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			self:_attack()
		end
	end)

	-- Sword visual
	self:_createSwordVisual()

	-- Listen for attack results (hit feedback)
	CombatService.AttackResult:Connect(function(hitCount: number, position: Vector3, direction: Vector3)
		if hitCount > 0 then
			self:_playHitEffect(position, direction)
		end
	end)

	-- Enemy hit VFX
	EnemyService.EnemyDamaged:Connect(function(model: Model, damage: number, position: Vector3)
		self:_showDamageNumber(position, damage)
		self:_flashEnemy(model)
	end)

	-- Enemy death VFX
	EnemyService.EnemyKilled:Connect(function(model: Model, enemyType: string)
		if model and model.PrimaryPart then
			self:_playDeathEffect(model.PrimaryPart.Position, model.PrimaryPart.Color)
		end
	end)
end

function CombatController:_playHitEffect(position: Vector3, direction: Vector3)
	-- Small particle burst at hit location
	local part = Instance.new("Part")
	part.Size = Vector3.new(0.5, 0.5, 0.5)
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Parent = workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 200, 50))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.2, 0.4)
	emitter.Speed = NumberRange.new(10, 20)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = part

	emitter:Emit(8)

	task.delay(1, function()
		part:Destroy()
	end)
end

function CombatController:_showDamageNumber(position: Vector3, damage: number)
	local cfg = GameConfig.VFX

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 100, 0, 40)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true

	local attachment = Instance.new("Part")
	attachment.Size = Vector3.new(0.1, 0.1, 0.1)
	attachment.Position = position + Vector3.new((math.random() - 0.5) * 2, 2, (math.random() - 0.5) * 2)
	attachment.Anchored = true
	attachment.CanCollide = false
	attachment.Transparency = 1
	attachment.Parent = workspace

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

	-- Animate upward and fade
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

	-- Burst of parts
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

		-- Fade and destroy
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

return CombatController
