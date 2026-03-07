--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local HUDController = Knit.CreateController({
	Name = "HUDController",
})

local _trove: any = nil
local _screenGui: ScreenGui = nil :: any
local _healthBar: Frame = nil :: any
local _healthFill: Frame = nil :: any
local _healthText: TextLabel = nil :: any
local _waveText: TextLabel = nil :: any
local _xpBar: Frame = nil :: any
local _xpFill: Frame = nil :: any
local _xpText: TextLabel = nil :: any
local _killsText: TextLabel = nil :: any
local _stateText: TextLabel = nil :: any
local _levelText: TextLabel = nil :: any
local _upgradeFrame: Frame = nil :: any

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

	-- Health Bar
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

	_healthBar = healthContainer

	-- XP Bar
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

	_xpBar = xpContainer

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

	-- State text (center)
	_stateText = createLabel(_screenGui, {
		Name = "StateText",
		Size = UDim2.new(0, 600, 0, 60),
		Position = UDim2.new(0.5, -300, 0.3, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		TextSize = 36,
		Font = Enum.Font.GothamBlack,
		TextTransparency = 0,
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

	-- Crosshair (center dot)
	local crosshair = Instance.new("Frame")
	crosshair.Name = "Crosshair"
	crosshair.Size = UDim2.new(0, 6, 0, 6)
	crosshair.Position = UDim2.new(0.5, -3, 0.5, -3)
	crosshair.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	crosshair.BackgroundTransparency = 0.3
	crosshair.BorderSizePixel = 0
	crosshair.Parent = _screenGui

	local crossCorner = Instance.new("UICorner")
	crossCorner.CornerRadius = UDim.new(1, 0)
	crossCorner.Parent = crosshair

	-- Upgrade frame (center, hidden by default)
	self:_buildUpgradeUI()
end

function HUDController:_buildUpgradeUI()
	_upgradeFrame = Instance.new("Frame")
	_upgradeFrame.Name = "UpgradeFrame"
	_upgradeFrame.Size = UDim2.new(0, 500, 0, 400)
	_upgradeFrame.Position = UDim2.new(0.5, -250, 0.5, -200)
	_upgradeFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	_upgradeFrame.BackgroundTransparency = 0.1
	_upgradeFrame.BorderSizePixel = 0
	_upgradeFrame.Visible = false
	_upgradeFrame.Parent = _screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = _upgradeFrame

	createLabel(_upgradeFrame, {
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.new(0, 0, 0, 10),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "UPGRADES",
		TextSize = 24,
		Font = Enum.Font.GothamBlack,
	})

	createLabel(_upgradeFrame, {
		Name = "PointsText",
		Size = UDim2.new(1, 0, 0, 25),
		Position = UDim2.new(0, 0, 0, 50),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Points: 0",
		TextSize = 16,
		TextColor3 = Color3.fromRGB(200, 200, 100),
	})

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 8)

	local itemsFrame = Instance.new("Frame")
	itemsFrame.Name = "Items"
	itemsFrame.Size = UDim2.new(1, -40, 1, -100)
	itemsFrame.Position = UDim2.new(0, 20, 0, 85)
	itemsFrame.BackgroundTransparency = 1
	itemsFrame.Parent = _upgradeFrame
	listLayout.Parent = itemsFrame

	-- Create upgrade buttons
	local order = 0
	for upgradeId, cfg in GameConfig.Upgrades :: any do
		order += 1
		local btn = Instance.new("TextButton")
		btn.Name = upgradeId
		btn.Size = UDim2.new(1, 0, 0, 60)
		btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
		btn.BorderSizePixel = 0
		btn.LayoutOrder = order
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 16
		btn.Text = `{cfg.Name}\n{cfg.Description}`
		btn.Parent = itemsFrame

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 8)
		btnCorner.Parent = btn

		btn.MouseButton1Click:Connect(function()
			local GameService = Knit.GetService("GameService")
			GameService:RequestUpgrade(upgradeId):catch(function(err)
				warn("Upgrade failed:", err)
			end)
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

	-- Upgrade points display
	local pointsLabel = _upgradeFrame:FindFirstChild("PointsText", true)
	if pointsLabel then
		(pointsLabel :: TextLabel).Text = `Upgrade Points: {stats.UpgradePoints}`
	end
end

function HUDController:ShowUpgradeMenu(show: boolean)
	_upgradeFrame.Visible = show
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
			self:ShowUpgradeMenu(false)
			self:ShowStateMessage(`Wave {wave}`, 2)
			_waveText.Text = `Wave {wave}`
		elseif state == "Intermission" then
			self:ShowUpgradeMenu(true)
			self:ShowStateMessage("Intermission - Buy Upgrades!", 3)
		elseif state == "GameOver" then
			self:ShowUpgradeMenu(false)
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
end

return HUDController
