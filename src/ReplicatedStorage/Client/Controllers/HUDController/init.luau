--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local HUDController = Knit.CreateController({
	Name = "HUDController",
})

local _screenGui: ScreenGui = nil :: any
local _healthFill: Frame = nil :: any
local _healthText: TextLabel = nil :: any
local _waveText: TextLabel = nil :: any
local _xpFill: Frame = nil :: any
local _xpText: TextLabel = nil :: any
local _killsText: TextLabel = nil :: any
local _stateText: TextLabel = nil :: any
local _levelText: TextLabel = nil :: any
local _cardFrame: Frame = nil :: any

local function createLabel(parent: Instance, props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextXAlignment = Enum.TextXAlignment.Left
	for k, v in props do
		(label :: any)[k] = v
	end
	label.Parent = parent
	return label
end

function HUDController:_buildUI()
	_screenGui = Instance.new("ScreenGui")
	_screenGui.Name = "OnslaughtHUD"
	_screenGui.ResetOnSpawn = false
	_screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	_screenGui.Parent = PlayerGui

	-- Health Bar (bottom left)
	local healthContainer = Instance.new("Frame")
	healthContainer.Name = "HealthContainer"
	healthContainer.Size = UDim2.new(0, 300, 0, 30)
	healthContainer.Position = UDim2.new(0, 20, 1, -60)
	healthContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	healthContainer.BorderSizePixel = 0
	healthContainer.Parent = _screenGui

	local healthCorner = Instance.new("UICorner")
	healthCorner.CornerRadius = UDim.new(0, 6)
	healthCorner.Parent = healthContainer

	_healthFill = Instance.new("Frame")
	_healthFill.Name = "Fill"
	_healthFill.Size = UDim2.new(1, 0, 1, 0)
	_healthFill.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
	_healthFill.BorderSizePixel = 0
	_healthFill.Parent = healthContainer

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = _healthFill

	_healthText = createLabel(healthContainer, {
		Name = "HealthText",
		Size = UDim2.new(1, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "100 / 100",
		TextSize = 16,
		ZIndex = 2,
	})

	-- XP Bar (bottom left, above health)
	local xpContainer = Instance.new("Frame")
	xpContainer.Name = "XPContainer"
	xpContainer.Size = UDim2.new(0, 300, 0, 14)
	xpContainer.Position = UDim2.new(0, 20, 1, -90)
	xpContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
	xpContainer.BorderSizePixel = 0
	xpContainer.Parent = _screenGui

	local xpCornerBg = Instance.new("UICorner")
	xpCornerBg.CornerRadius = UDim.new(0, 4)
	xpCornerBg.Parent = xpContainer

	_xpFill = Instance.new("Frame")
	_xpFill.Name = "Fill"
	_xpFill.Size = UDim2.new(0, 0, 1, 0)
	_xpFill.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
	_xpFill.BorderSizePixel = 0
	_xpFill.Parent = xpContainer

	local xpFillCorner = Instance.new("UICorner")
	xpFillCorner.CornerRadius = UDim.new(0, 4)
	xpFillCorner.Parent = _xpFill

	_xpText = createLabel(xpContainer, {
		Name = "XPText",
		Size = UDim2.new(1, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "XP: 0",
		TextSize = 11,
		ZIndex = 2,
	})

	-- Level text
	_levelText = createLabel(_screenGui, {
		Name = "LevelText",
		Size = UDim2.new(0, 200, 0, 30),
		Position = UDim2.new(0, 20, 1, -120),
		Text = "Level 1",
		TextSize = 20,
		Font = Enum.Font.GothamBold,
	})

	-- Wave info (top center)
	_waveText = createLabel(_screenGui, {
		Name = "WaveText",
		Size = UDim2.new(0, 400, 0, 40),
		Position = UDim2.new(0.5, -200, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Wave 1",
		TextSize = 28,
		Font = Enum.Font.GothamBlack,
	})

	-- State text (upper center, for announcements)
	_stateText = createLabel(_screenGui, {
		Name = "StateText",
		Size = UDim2.new(0, 600, 0, 60),
		Position = UDim2.new(0.5, -300, 0.25, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		TextSize = 36,
		Font = Enum.Font.GothamBlack,
		TextTransparency = 1,
	})

	-- Kills (top right)
	_killsText = createLabel(_screenGui, {
		Name = "KillsText",
		Size = UDim2.new(0, 200, 0, 30),
		Position = UDim2.new(1, -220, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "Kills: 0",
		TextSize = 20,
	})

	-- Level-up card picker frame (hidden by default)
	self:_buildCardFrame()
end

function HUDController:_buildCardFrame()
	_cardFrame = Instance.new("Frame")
	_cardFrame.Name = "CardFrame"
	_cardFrame.Size = UDim2.new(1, 0, 1, 0)
	_cardFrame.Position = UDim2.new(0, 0, 0, 0)
	_cardFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	_cardFrame.BackgroundTransparency = 0.5
	_cardFrame.BorderSizePixel = 0
	_cardFrame.Visible = false
	_cardFrame.ZIndex = 50
	_cardFrame.Parent = _screenGui

	createLabel(_cardFrame, {
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 50),
		Position = UDim2.new(0, 0, 0.15, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "LEVEL UP! Choose an upgrade:",
		TextSize = 30,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(255, 220, 50),
		ZIndex = 51,
	})
end

function HUDController:ShowUpgradeCards(cards: { { Id: string, Name: string, Description: string } })
	-- Clear old cards
	for _, child in _cardFrame:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	_cardFrame.Visible = true

	local cardWidth = 160
	local cardHeight = 200
	local gap = 20
	local totalWidth = #cards * cardWidth + (#cards - 1) * gap
	local startX = -totalWidth / 2

	for i, card in cards do
		local btn = Instance.new("TextButton")
		btn.Name = card.Id
		btn.Size = UDim2.new(0, cardWidth, 0, cardHeight)
		btn.Position = UDim2.new(0.5, startX + (i - 1) * (cardWidth + gap), 0.5, -cardHeight / 2)
		btn.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
		btn.BorderSizePixel = 0
		btn.Text = ""
		btn.AutoButtonColor = true
		btn.ZIndex = 52
		btn.Parent = _cardFrame

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 12)
		btnCorner.Parent = btn

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(100, 100, 200)
		stroke.Thickness = 2
		stroke.Parent = btn

		-- Card name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -16, 0, 40)
		nameLabel.Position = UDim2.new(0, 8, 0, 20)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = card.Name
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.Font = Enum.Font.GothamBlack
		nameLabel.TextSize = 18
		nameLabel.TextWrapped = true
		nameLabel.ZIndex = 53
		nameLabel.Parent = btn

		-- Card description
		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(1, -16, 0, 80)
		descLabel.Position = UDim2.new(0, 8, 0, 80)
		descLabel.BackgroundTransparency = 1
		descLabel.Text = card.Description
		descLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
		descLabel.Font = Enum.Font.GothamBold
		descLabel.TextSize = 14
		descLabel.TextWrapped = true
		descLabel.ZIndex = 53
		descLabel.Parent = btn

		btn.MouseButton1Click:Connect(function()
			_cardFrame.Visible = false
			local GameService = Knit.GetService("GameService")
			GameService:PickUpgradeCard(card.Id):catch(function(err)
				warn("Card pick failed:", err)
			end)
		end)

		-- Hover effect
		btn.MouseEnter:Connect(function()
			btn.BackgroundColor3 = Color3.fromRGB(50, 50, 80)
			stroke.Color = Color3.fromRGB(180, 180, 255)
		end)
		btn.MouseLeave:Connect(function()
			btn.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
			stroke.Color = Color3.fromRGB(100, 100, 200)
		end)
	end
end

function HUDController:UpdateStats(stats: any)
	if not stats then
		return
	end

	-- Health bar
	local healthPct = stats.Health / stats.MaxHealth
	_healthFill.Size = UDim2.new(math.clamp(healthPct, 0, 1), 0, 1, 0)
	_healthText.Text = `{math.floor(stats.Health)} / {stats.MaxHealth}`

	if healthPct > 0.5 then
		_healthFill.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
	elseif healthPct > 0.25 then
		_healthFill.BackgroundColor3 = Color3.fromRGB(220, 180, 30)
	else
		_healthFill.BackgroundColor3 = Color3.fromRGB(220, 40, 40)
	end

	-- XP bar
	local xpCfg = GameConfig.XP
	local xpNeeded = xpCfg.BaseXPToLevel * (xpCfg.XPScaling ^ (stats.Level - 1))
	local xpPct = stats.XP / xpNeeded
	_xpFill.Size = UDim2.new(math.clamp(xpPct, 0, 1), 0, 1, 0)
	_xpText.Text = `XP: {stats.XP} / {math.floor(xpNeeded)}`

	-- Level
	_levelText.Text = `Level {stats.Level}`

	-- Kills
	_killsText.Text = `Kills: {stats.Kills}`
end

function HUDController:ShowStateMessage(text: string, duration: number?)
	_stateText.Text = text
	_stateText.TextTransparency = 0
	if duration then
		task.delay(duration, function()
			if _stateText.Text == text then
				_stateText.TextTransparency = 1
			end
		end)
	end
end

function HUDController:KnitInit()
	self:_buildUI()
end

function HUDController:KnitStart()
	local GameService = Knit.GetService("GameService")

	-- Get initial stats
	task.spawn(function()
		local ok, stats = GameService:GetPlayerStats():await()
		if ok and stats then
			self:UpdateStats(stats)
		end
	end)

	-- Listen for stat updates
	GameService.PlayerStatsChanged:Connect(function(stats: any)
		self:UpdateStats(stats)
	end)

	-- Game state changes
	GameService.GameStateChanged:Connect(function(state: string, wave: number)
		if state == "Wave" then
			_cardFrame.Visible = false
			self:ShowStateMessage(`Wave {wave}`, 2)
			_waveText.Text = `Wave {wave}`
		elseif state == "Intermission" then
			self:ShowStateMessage("Wave cleared!", 2)
		elseif state == "GameOver" then
			_cardFrame.Visible = false
			self:ShowStateMessage("GAME OVER", 3)
		end
	end)

	-- Wave changes
	GameService.WaveChanged:Connect(function(wave: number, enemyCount: number)
		_waveText.Text = `Wave {wave} - {enemyCount} enemies`
	end)

	-- Intermission countdown
	GameService.IntermissionTick:Connect(function(seconds: number)
		_stateText.Text = `Next wave in {seconds}...`
		_stateText.TextTransparency = 0
	end)

	-- Damage vignette
	GameService.PlayerDamaged:Connect(function(_damage: number)
		self:_showDamageVignette()
	end)

	-- Level-up upgrade cards
	GameService.ShowUpgradeCards:Connect(function(cards: any)
		self:ShowUpgradeCards(cards)
	end)
end

function HUDController:_showDamageVignette()
	local vignette = Instance.new("Frame")
	vignette.Name = "DamageVignette"
	vignette.Size = UDim2.new(1, 0, 1, 0)
	vignette.Position = UDim2.new(0, 0, 0, 0)
	vignette.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
	vignette.BackgroundTransparency = 0.7
	vignette.BorderSizePixel = 0
	vignette.ZIndex = 100
	vignette.Parent = _screenGui

	task.spawn(function()
		local elapsed = 0
		local duration = 0.3
		while elapsed < duration do
			local dt = RunService.RenderStepped:Wait()
			elapsed += dt
			vignette.BackgroundTransparency = 0.7 + (elapsed / duration) * 0.3
		end
		vignette:Destroy()
	end)
end

return HUDController
