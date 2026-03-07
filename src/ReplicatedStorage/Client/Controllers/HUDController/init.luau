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
local _timerText: TextLabel = nil :: any
local _weaponListFrame: Frame = nil :: any
local _gameOverFrame: Frame = nil :: any

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

local function formatTime(seconds: number): string
	local mins = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%d:%02d", mins, secs)
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

	-- XP Bar (bottom, full width)
	local xpContainer = Instance.new("Frame")
	xpContainer.Name = "XPContainer"
	xpContainer.Size = UDim2.new(1, -40, 0, 14)
	xpContainer.Position = UDim2.new(0, 20, 1, -20)
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
		Position = UDim2.new(0, 20, 1, -100),
		Text = "Level 1",
		TextSize = 20,
		Font = Enum.Font.GothamBold,
	})

	-- Timer (top center)
	_timerText = createLabel(_screenGui, {
		Name = "TimerText",
		Size = UDim2.new(0, 200, 0, 30),
		Position = UDim2.new(0.5, -100, 0, 10),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "0:00",
		TextSize = 22,
		Font = Enum.Font.GothamBlack,
	})

	-- Wave info (top center, below timer)
	_waveText = createLabel(_screenGui, {
		Name = "WaveText",
		Size = UDim2.new(0, 400, 0, 30),
		Position = UDim2.new(0.5, -200, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Wave 1",
		TextSize = 22,
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

	-- Weapon list (left side)
	self:_buildWeaponList()

	-- Level-up card picker frame (hidden by default)
	self:_buildCardFrame()

	-- Game over screen (hidden by default)
	self:_buildGameOverFrame()
end

-------------------------------------------------
-- WEAPON LIST
-------------------------------------------------

function HUDController:_buildWeaponList()
	_weaponListFrame = Instance.new("Frame")
	_weaponListFrame.Name = "WeaponList"
	_weaponListFrame.Size = UDim2.new(0, 140, 0, 200)
	_weaponListFrame.Position = UDim2.new(0, 10, 0.5, -100)
	_weaponListFrame.BackgroundTransparency = 1
	_weaponListFrame.BorderSizePixel = 0
	_weaponListFrame.Parent = _screenGui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, 4)
	layout.Parent = _weaponListFrame
end

function HUDController:_updateWeaponList(stats: any)
	if not _weaponListFrame then
		return
	end

	-- Clear old weapon entries
	for _, child in _weaponListFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local weapons = { "Orbiter" } -- Always have orbiter
	local upgrades = stats.Upgrades or {}

	if upgrades["NewProjectile"] then
		table.insert(weapons, "Projectile")
	end
	if upgrades["NewLightning"] then
		table.insert(weapons, "Lightning")
	end
	if upgrades["NewAura"] then
		table.insert(weapons, "Aura")
	end

	local weaponColors = {
		Orbiter = GameConfig.Weapons.Orbiter.Color,
		Projectile = GameConfig.Weapons.Projectile.Color,
		Lightning = GameConfig.Weapons.Lightning.BeamColor,
		Aura = GameConfig.Weapons.Aura.Color,
	}

	for _, weaponName in weapons do
		local entry = Instance.new("Frame")
		entry.Name = weaponName
		entry.Size = UDim2.new(1, 0, 0, 24)
		entry.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
		entry.BackgroundTransparency = 0.4
		entry.BorderSizePixel = 0
		entry.Parent = _weaponListFrame

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = entry

		-- Color dot
		local dot = Instance.new("Frame")
		dot.Size = UDim2.new(0, 12, 0, 12)
		dot.Position = UDim2.new(0, 6, 0.5, -6)
		dot.BackgroundColor3 = weaponColors[weaponName] or Color3.fromRGB(200, 200, 200)
		dot.BorderSizePixel = 0
		dot.Parent = entry

		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(1, 0)
		dotCorner.Parent = dot

		createLabel(entry, {
			Name = "WeaponName",
			Size = UDim2.new(1, -26, 1, 0),
			Position = UDim2.new(0, 24, 0, 0),
			Text = weaponName,
			TextSize = 13,
			Font = Enum.Font.GothamBold,
		})
	end
end

-------------------------------------------------
-- CARD FRAME
-------------------------------------------------

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

-------------------------------------------------
-- GAME OVER SCREEN
-------------------------------------------------

function HUDController:_buildGameOverFrame()
	_gameOverFrame = Instance.new("Frame")
	_gameOverFrame.Name = "GameOverFrame"
	_gameOverFrame.Size = UDim2.new(1, 0, 1, 0)
	_gameOverFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	_gameOverFrame.BackgroundTransparency = 0.3
	_gameOverFrame.BorderSizePixel = 0
	_gameOverFrame.Visible = false
	_gameOverFrame.ZIndex = 60
	_gameOverFrame.Parent = _screenGui

	createLabel(_gameOverFrame, {
		Name = "GameOverTitle",
		Size = UDim2.new(1, 0, 0, 60),
		Position = UDim2.new(0, 0, 0.2, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "GAME OVER",
		TextSize = 48,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(220, 40, 40),
		ZIndex = 61,
	})

	createLabel(_gameOverFrame, {
		Name = "SurvivalTime",
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0.35, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Survival Time: 0:00",
		TextSize = 22,
		ZIndex = 61,
	})

	createLabel(_gameOverFrame, {
		Name = "KillsStat",
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0.4, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Kills: 0",
		TextSize = 22,
		ZIndex = 61,
	})

	createLabel(_gameOverFrame, {
		Name = "LevelStat",
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0.45, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Level: 1",
		TextSize = 22,
		ZIndex = 61,
	})

	createLabel(_gameOverFrame, {
		Name = "WaveStat",
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0.5, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Wave: 1",
		TextSize = 22,
		ZIndex = 61,
	})

	local playAgainBtn = Instance.new("TextButton")
	playAgainBtn.Name = "PlayAgainBtn"
	playAgainBtn.Size = UDim2.new(0, 200, 0, 50)
	playAgainBtn.Position = UDim2.new(0.5, -100, 0.6, 0)
	playAgainBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
	playAgainBtn.BorderSizePixel = 0
	playAgainBtn.Text = "Play Again"
	playAgainBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	playAgainBtn.Font = Enum.Font.GothamBlack
	playAgainBtn.TextSize = 24
	playAgainBtn.AutoButtonColor = true
	playAgainBtn.ZIndex = 62
	playAgainBtn.Parent = _gameOverFrame

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 10)
	btnCorner.Parent = playAgainBtn

	playAgainBtn.MouseButton1Click:Connect(function()
		_gameOverFrame.Visible = false
		local GameService = Knit.GetService("GameService")
		GameService:PlayAgain():catch(function(err)
			warn("PlayAgain failed:", err)
		end)
	end)
end

function HUDController:ShowGameOver(data: any)
	if not _gameOverFrame then
		return
	end

	_gameOverFrame.Visible = true

	local survTime = _gameOverFrame:FindFirstChild("SurvivalTime") :: TextLabel?
	if survTime then
		survTime.Text = `Survival Time: {formatTime(data.SurvivalTime)}`
	end

	local killsStat = _gameOverFrame:FindFirstChild("KillsStat") :: TextLabel?
	if killsStat then
		killsStat.Text = `Kills: {data.Kills}`
	end

	local levelStat = _gameOverFrame:FindFirstChild("LevelStat") :: TextLabel?
	if levelStat then
		levelStat.Text = `Level: {data.Level}`
	end

	local waveStat = _gameOverFrame:FindFirstChild("WaveStat") :: TextLabel?
	if waveStat then
		waveStat.Text = `Wave: {data.Wave}`
	end
end

-------------------------------------------------
-- STATS UPDATE
-------------------------------------------------

function HUDController:UpdateStats(stats: any)
	if not stats then
		return
	end

	-- Dismiss cards if player died
	if stats.Health <= 0 then
		_cardFrame.Visible = false
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

	-- Weapon list
	self:_updateWeaponList(stats)
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
			_gameOverFrame.Visible = false
			self:ShowStateMessage(`Wave {wave}`, 2)
			_waveText.Text = `Wave {wave}`
		elseif state == "Intermission" then
			self:ShowStateMessage("Wave cleared!", 2)
		elseif state == "GameOver" then
			_cardFrame.Visible = false
			self:ShowStateMessage("GAME OVER", 3)
		elseif state == "WaitingForPlayers" then
			_gameOverFrame.Visible = false
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

	-- Game timer
	GameService.GameTimerTick:Connect(function(elapsed: number)
		_timerText.Text = formatTime(elapsed)
	end)

	-- Game over data
	GameService.GameOverData:Connect(function(data: any)
		self:ShowGameOver(data)
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
