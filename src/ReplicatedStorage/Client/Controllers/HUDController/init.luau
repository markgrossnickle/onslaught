--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local RelicData = require(ReplicatedStorage.Shared.RelicData)
local CharacterData = require(ReplicatedStorage.Shared.CharacterData)

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
local _soulsText: TextLabel = nil :: any
local _lobbyFrame: Frame = nil :: any
local _bossBarFrame: Frame = nil :: any
local _bossBarFill: Frame = nil :: any
local _bossBarTitle: TextLabel = nil :: any
local _buffFrame: Frame = nil :: any
local _activeBuffIcons: { [string]: { Frame: Frame, EndTime: number } } = {}

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

local function createButton(parent: Instance, props: { [string]: any }): TextButton
	local btn = Instance.new("TextButton")
	btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 16
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = true
	for k, v in props do
		(btn :: any)[k] = v
	end
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn
	btn.Parent = parent
	return btn
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

	-- Souls (top right, below kills)
	_soulsText = createLabel(_screenGui, {
		Name = "SoulsText",
		Size = UDim2.new(0, 200, 0, 24),
		Position = UDim2.new(1, -220, 0, 50),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "Souls: 0",
		TextSize = 16,
		TextColor3 = Color3.fromRGB(200, 160, 255),
	})

	-- Weapon list (left side)
	self:_buildWeaponList()

	-- Level-up card picker frame (hidden by default)
	self:_buildCardFrame()

	-- Game over screen (hidden by default)
	self:_buildGameOverFrame()

	-- Lobby frame (hidden by default)
	self:_buildLobbyFrame()

	-- Boss health bar (hidden by default)
	self:_buildBossBar()

	-- Buff indicator strip
	self:_buildBuffFrame()
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

	for _, child in _weaponListFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local weapons = { "Orbiter" }
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
		Position = UDim2.new(0, 0, 0.15, 0),
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
		Position = UDim2.new(0, 0, 0.3, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Survival Time: 0:00",
		TextSize = 22,
		ZIndex = 61,
	})

	createLabel(_gameOverFrame, {
		Name = "KillsStat",
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0.35, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Kills: 0",
		TextSize = 22,
		ZIndex = 61,
	})

	createLabel(_gameOverFrame, {
		Name = "LevelStat",
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0.4, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Level: 1",
		TextSize = 22,
		ZIndex = 61,
	})

	createLabel(_gameOverFrame, {
		Name = "WaveStat",
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0.45, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Wave: 1",
		TextSize = 22,
		ZIndex = 61,
	})

	createLabel(_gameOverFrame, {
		Name = "SoulsEarned",
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0.52, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		TextSize = 24,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(200, 160, 255),
		ZIndex = 61,
	})

	local playAgainBtn = Instance.new("TextButton")
	playAgainBtn.Name = "PlayAgainBtn"
	playAgainBtn.Size = UDim2.new(0, 200, 0, 50)
	playAgainBtn.Position = UDim2.new(0.5, -100, 0.6, 0)
	playAgainBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
	playAgainBtn.BorderSizePixel = 0
	playAgainBtn.Text = "Continue"
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

	local title = _gameOverFrame:FindFirstChild("GameOverTitle") :: TextLabel?
	if title then
		if data.Victory then
			title.Text = "VICTORY!"
			title.TextColor3 = Color3.fromRGB(255, 220, 50)
		else
			title.Text = "GAME OVER"
			title.TextColor3 = Color3.fromRGB(220, 40, 40)
		end
	end

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
-- LOBBY FRAME (Relic Shop + Character Select + Ready Up)
-------------------------------------------------

function HUDController:_buildLobbyFrame()
	_lobbyFrame = Instance.new("Frame")
	_lobbyFrame.Name = "LobbyFrame"
	_lobbyFrame.Size = UDim2.new(1, 0, 1, 0)
	_lobbyFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	_lobbyFrame.BackgroundTransparency = 0.4
	_lobbyFrame.BorderSizePixel = 0
	_lobbyFrame.Visible = false
	_lobbyFrame.ZIndex = 70
	_lobbyFrame.Parent = _screenGui

	createLabel(_lobbyFrame, {
		Name = "LobbyTitle",
		Size = UDim2.new(1, 0, 0, 50),
		Position = UDim2.new(0, 0, 0.02, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "PREPARE FOR NEXT RUN",
		TextSize = 32,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(200, 160, 255),
		ZIndex = 71,
	})
end

function HUDController:_showLobby()
	if not _lobbyFrame then
		return
	end

	-- Clear old content (keep title)
	for _, child in _lobbyFrame:GetChildren() do
		if child:IsA("ScrollingFrame") or child:IsA("Frame") or child:IsA("TextButton") then
			child:Destroy()
		end
	end

	_lobbyFrame.Visible = true

	local StatsService = Knit.GetService("StatsService")

	-- Fetch player data
	task.spawn(function()
		local ok1, souls = StatsService:GetSouls():await()
		local ok2, relicLevels = StatsService:GetRelicLevels():await()
		local ok3, selectedChar = StatsService:GetSelectedCharacter():await()
		local ok4, unlockedWeapons = StatsService:GetUnlockedWeapons():await()
		local ok5, lifetimeStats = StatsService:GetLifetimeStats():await()

		if not (ok1 and ok2 and ok3 and ok4 and ok5) then
			warn("Failed to load lobby data")
			return
		end

		-- Souls display
		local soulsLabel = createLabel(_lobbyFrame, {
			Name = "LobbySouls",
			Size = UDim2.new(1, 0, 0, 30),
			Position = UDim2.new(0, 0, 0.07, 0),
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = `Souls: {souls}`,
			TextSize = 22,
			TextColor3 = Color3.fromRGB(200, 160, 255),
			ZIndex = 71,
		})

		-- RELIC SHOP (left panel)
		self:_buildRelicShop(relicLevels, souls, soulsLabel)

		-- CHARACTER SELECT (center panel)
		self:_buildCharacterSelect(selectedChar, unlockedWeapons)

		-- STATS PANEL (right panel)
		self:_buildStatsPanel(lifetimeStats, unlockedWeapons)

		-- READY UP button (bottom center)
		local readyBtn = createButton(_lobbyFrame, {
			Name = "ReadyBtn",
			Size = UDim2.new(0, 220, 0, 50),
			Position = UDim2.new(0.5, -110, 0.9, 0),
			BackgroundColor3 = Color3.fromRGB(50, 200, 50),
			Text = "READY UP",
			Font = Enum.Font.GothamBlack,
			TextSize = 24,
			ZIndex = 72,
		})

		readyBtn.MouseButton1Click:Connect(function()
			readyBtn.Text = "READY!"
			readyBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
			local GameService = Knit.GetService("GameService")
			GameService:ReadyUp():catch(function(err)
				warn("ReadyUp failed:", err)
			end)
		end)
	end)
end

function HUDController:_buildRelicShop(relicLevels: { [string]: number }, souls: number, _soulsLabel: TextLabel)
	local shopFrame = Instance.new("ScrollingFrame")
	shopFrame.Name = "RelicShop"
	shopFrame.Size = UDim2.new(0.3, -20, 0.7, 0)
	shopFrame.Position = UDim2.new(0, 20, 0.12, 0)
	shopFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	shopFrame.BackgroundTransparency = 0.3
	shopFrame.BorderSizePixel = 0
	shopFrame.ScrollBarThickness = 4
	shopFrame.CanvasSize = UDim2.new(0, 0, 0, #RelicData.Relics * 75 + 40)
	shopFrame.ZIndex = 71
	shopFrame.Parent = _lobbyFrame

	local shopCorner = Instance.new("UICorner")
	shopCorner.CornerRadius = UDim.new(0, 8)
	shopCorner.Parent = shopFrame

	createLabel(shopFrame, {
		Name = "ShopTitle",
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 10, 0, 5),
		Text = "Relic Shop",
		TextSize = 20,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(200, 160, 255),
		ZIndex = 72,
	})

	local currentSouls = souls
	for i, relic in RelicData.Relics do
		local tier = relicLevels[relic.Id] or 0
		local cost = RelicData.GetUpgradeCost(relic.Id, tier)
		local isMaxed = tier >= relic.MaxTier
		local yPos = 35 + (i - 1) * 75

		local entry = Instance.new("Frame")
		entry.Name = relic.Id
		entry.Size = UDim2.new(1, -20, 0, 65)
		entry.Position = UDim2.new(0, 10, 0, yPos)
		entry.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
		entry.BorderSizePixel = 0
		entry.ZIndex = 72
		entry.Parent = shopFrame

		local entryCorner = Instance.new("UICorner")
		entryCorner.CornerRadius = UDim.new(0, 6)
		entryCorner.Parent = entry

		createLabel(entry, {
			Size = UDim2.new(0.6, 0, 0, 20),
			Position = UDim2.new(0, 8, 0, 4),
			Text = `{relic.Name} ({tier}/{relic.MaxTier})`,
			TextSize = 14,
			Font = Enum.Font.GothamBlack,
			ZIndex = 73,
		})

		createLabel(entry, {
			Size = UDim2.new(0.9, 0, 0, 16),
			Position = UDim2.new(0, 8, 0, 24),
			Text = relic.Description,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(160, 160, 180),
			ZIndex = 73,
		})

		if not isMaxed and cost then
			local buyBtn = createButton(entry, {
				Size = UDim2.new(0, 80, 0, 24),
				Position = UDim2.new(1, -90, 0, 36),
				Text = `{cost} Souls`,
				TextSize = 12,
				BackgroundColor3 = if currentSouls >= cost
					then Color3.fromRGB(80, 60, 160)
					else Color3.fromRGB(60, 60, 60),
				ZIndex = 74,
			})

			buyBtn.MouseButton1Click:Connect(function()
				local StatsService = Knit.GetService("StatsService")
				local okPurchase, result = StatsService:PurchaseRelic(relic.Id):await()
				if okPurchase and result then
					-- Refresh lobby
					self:_showLobby()
				end
			end)
		else
			createLabel(entry, {
				Size = UDim2.new(0, 80, 0, 24),
				Position = UDim2.new(1, -90, 0, 36),
				Text = "MAXED",
				TextSize = 12,
				TextColor3 = Color3.fromRGB(100, 200, 100),
				ZIndex = 73,
			})
		end
	end
end

function HUDController:_buildCharacterSelect(selectedChar: string, _unlockedWeapons: { [string]: boolean })
	local charFrame = Instance.new("Frame")
	charFrame.Name = "CharacterSelect"
	charFrame.Size = UDim2.new(0.35, -20, 0.5, 0)
	charFrame.Position = UDim2.new(0.3, 10, 0.12, 0)
	charFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	charFrame.BackgroundTransparency = 0.3
	charFrame.BorderSizePixel = 0
	charFrame.ZIndex = 71
	charFrame.Parent = _lobbyFrame

	local charCorner = Instance.new("UICorner")
	charCorner.CornerRadius = UDim.new(0, 8)
	charCorner.Parent = charFrame

	createLabel(charFrame, {
		Name = "CharTitle",
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 10, 0, 5),
		Text = "Character Select",
		TextSize = 20,
		Font = Enum.Font.GothamBlack,
		ZIndex = 72,
	})

	local cardWidth = 120
	local gap = 10
	local chars = CharacterData.Characters
	local totalWidth = #chars * cardWidth + (#chars - 1) * gap
	local startX = (charFrame.AbsoluteSize.X - totalWidth) / 2
	if startX < 10 then
		startX = 10
	end

	for i, charDef in chars do
		local isSelected = charDef.Id == selectedChar
		local xPos = startX + (i - 1) * (cardWidth + gap)

		local card = Instance.new("TextButton")
		card.Name = charDef.Id
		card.Size = UDim2.new(0, cardWidth, 0, 160)
		card.Position = UDim2.new(0, xPos, 0, 40)
		card.BackgroundColor3 = if isSelected then Color3.fromRGB(50, 50, 80) else Color3.fromRGB(30, 30, 45)
		card.BorderSizePixel = 0
		card.Text = ""
		card.AutoButtonColor = true
		card.ZIndex = 72
		card.Parent = charFrame

		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 8)
		cardCorner.Parent = card

		if isSelected then
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(200, 160, 255)
			stroke.Thickness = 2
			stroke.Parent = card
		end

		-- Color swatch
		local swatch = Instance.new("Frame")
		swatch.Size = UDim2.new(0, 40, 0, 40)
		swatch.Position = UDim2.new(0.5, -20, 0, 10)
		swatch.BackgroundColor3 = charDef.Color
		swatch.BorderSizePixel = 0
		swatch.ZIndex = 73
		swatch.Parent = card

		local swatchCorner = Instance.new("UICorner")
		swatchCorner.CornerRadius = UDim.new(0, 6)
		swatchCorner.Parent = swatch

		createLabel(card, {
			Size = UDim2.new(1, -8, 0, 20),
			Position = UDim2.new(0, 4, 0, 55),
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = charDef.Name,
			TextSize = 14,
			Font = Enum.Font.GothamBlack,
			ZIndex = 73,
		})

		createLabel(card, {
			Size = UDim2.new(1, -8, 0, 60),
			Position = UDim2.new(0, 4, 0, 78),
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = charDef.Description,
			TextSize = 10,
			TextWrapped = true,
			TextColor3 = Color3.fromRGB(180, 180, 200),
			ZIndex = 73,
		})

		card.MouseButton1Click:Connect(function()
			local StatsService = Knit.GetService("StatsService")
			StatsService:SelectCharacter(charDef.Id):catch(function(err)
				warn("Select character failed:", err)
			end)
			-- Refresh lobby to show selection
			task.delay(0.2, function()
				self:_showLobby()
			end)
		end)
	end
end

function HUDController:_buildStatsPanel(lifetimeStats: { [string]: any }, unlockedWeapons: { [string]: boolean })
	local statsFrame = Instance.new("Frame")
	statsFrame.Name = "StatsPanel"
	statsFrame.Size = UDim2.new(0.35, -20, 0.7, 0)
	statsFrame.Position = UDim2.new(0.65, 10, 0.12, 0)
	statsFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	statsFrame.BackgroundTransparency = 0.3
	statsFrame.BorderSizePixel = 0
	statsFrame.ZIndex = 71
	statsFrame.Parent = _lobbyFrame

	local statsCorner = Instance.new("UICorner")
	statsCorner.CornerRadius = UDim.new(0, 8)
	statsCorner.Parent = statsFrame

	createLabel(statsFrame, {
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 10, 0, 5),
		Text = "Stats & Unlocks",
		TextSize = 20,
		Font = Enum.Font.GothamBlack,
		ZIndex = 72,
	})

	local statTexts = {
		`Total Kills: {lifetimeStats.TotalKills}`,
		`Best Wave: {lifetimeStats.BestWave}`,
		`Best Time: {formatTime(lifetimeStats.BestSurvivalTime)}`,
		`Total Runs: {lifetimeStats.TotalRuns}`,
	}

	for i, text in statTexts do
		createLabel(statsFrame, {
			Size = UDim2.new(1, -20, 0, 22),
			Position = UDim2.new(0, 10, 0, 35 + (i - 1) * 24),
			Text = text,
			TextSize = 14,
			ZIndex = 72,
		})
	end

	-- Weapon unlock progress
	createLabel(statsFrame, {
		Size = UDim2.new(1, -20, 0, 24),
		Position = UDim2.new(0, 10, 0, 140),
		Text = "Weapon Unlocks",
		TextSize = 16,
		Font = Enum.Font.GothamBlack,
		ZIndex = 72,
	})

	local weaponUnlocks = {
		{ Id = "Orbiter", Name = "Orbiter", Condition = "Default" },
		{ Id = "Projectile", Name = "Projectile", Condition = "Reach Wave 5" },
		{ Id = "Lightning", Name = "Lightning", Condition = "200 Total Kills" },
		{ Id = "Aura", Name = "Aura", Condition = "Survive 5 Minutes" },
	}

	for i, weapon in weaponUnlocks do
		local isUnlocked = unlockedWeapons[weapon.Id] or false
		local color = if isUnlocked then Color3.fromRGB(100, 255, 100) else Color3.fromRGB(150, 150, 150)
		local statusText = if isUnlocked then "UNLOCKED" else weapon.Condition

		createLabel(statsFrame, {
			Size = UDim2.new(1, -20, 0, 20),
			Position = UDim2.new(0, 10, 0, 166 + (i - 1) * 22),
			Text = `{weapon.Name}: {statusText}`,
			TextSize = 12,
			TextColor3 = color,
			ZIndex = 72,
		})
	end
end

-------------------------------------------------
-- BUFF INDICATORS
-------------------------------------------------

function HUDController:_buildBuffFrame()
	_buffFrame = Instance.new("Frame")
	_buffFrame.Name = "BuffFrame"
	_buffFrame.Size = UDim2.new(0, 300, 0, 32)
	_buffFrame.Position = UDim2.new(0, 20, 1, -140)
	_buffFrame.BackgroundTransparency = 1
	_buffFrame.BorderSizePixel = 0
	_buffFrame.Parent = _screenGui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.Parent = _buffFrame
end

function HUDController:ShowBuff(buffType: string, duration: number)
	if not _buffFrame then
		return
	end

	local puCfg = (GameConfig.PowerUps.Types :: any)[buffType]
	if not puCfg then
		return
	end

	-- Remove existing icon for same buff
	if _activeBuffIcons[buffType] then
		_activeBuffIcons[buffType].Frame:Destroy()
		_activeBuffIcons[buffType] = nil
	end

	local icon = Instance.new("Frame")
	icon.Name = buffType
	icon.Size = UDim2.new(0, 90, 0, 28)
	icon.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	icon.BackgroundTransparency = 0.3
	icon.BorderSizePixel = 0
	icon.Parent = _buffFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = icon

	local dot = Instance.new("Frame")
	dot.Size = UDim2.new(0, 10, 0, 10)
	dot.Position = UDim2.new(0, 4, 0.5, -5)
	dot.BackgroundColor3 = puCfg.Color
	dot.BorderSizePixel = 0
	dot.Parent = icon

	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = dot

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "BuffName"
	nameLabel.Size = UDim2.new(1, -50, 1, 0)
	nameLabel.Position = UDim2.new(0, 18, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = puCfg.Name
	nameLabel.TextColor3 = puCfg.Color
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 11
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = icon

	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "Timer"
	timerLabel.Size = UDim2.new(0, 30, 1, 0)
	timerLabel.Position = UDim2.new(1, -34, 0, 0)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Text = tostring(math.ceil(duration))
	timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	timerLabel.Font = Enum.Font.GothamBold
	timerLabel.TextSize = 12
	timerLabel.TextXAlignment = Enum.TextXAlignment.Right
	timerLabel.Parent = icon

	_activeBuffIcons[buffType] = {
		Frame = icon,
		EndTime = tick() + duration,
	}
end

function HUDController:RemoveBuff(buffType: string)
	local entry = _activeBuffIcons[buffType]
	if entry then
		entry.Frame:Destroy()
		_activeBuffIcons[buffType] = nil
	end
end

function HUDController:_updateBuffTimers()
	local now = tick()
	for buffType, entry in _activeBuffIcons do
		local remaining = math.max(0, entry.EndTime - now)
		local timerLabel = entry.Frame:FindFirstChild("Timer") :: TextLabel?
		if timerLabel then
			timerLabel.Text = tostring(math.ceil(remaining))
		end
		if remaining <= 0 then
			entry.Frame:Destroy()
			_activeBuffIcons[buffType] = nil
		end
	end
end

-------------------------------------------------
-- BOSS HEALTH BAR
-------------------------------------------------

function HUDController:_buildBossBar()
	_bossBarFrame = Instance.new("Frame")
	_bossBarFrame.Name = "BossBar"
	_bossBarFrame.Size = UDim2.new(0.6, 0, 0, 32)
	_bossBarFrame.Position = UDim2.new(0.2, 0, 0, 75)
	_bossBarFrame.BackgroundColor3 = Color3.fromRGB(20, 10, 30)
	_bossBarFrame.BorderSizePixel = 0
	_bossBarFrame.Visible = false
	_bossBarFrame.ZIndex = 80
	_bossBarFrame.Parent = _screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = _bossBarFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 40, 140)
	stroke.Thickness = 2
	stroke.Parent = _bossBarFrame

	_bossBarFill = Instance.new("Frame")
	_bossBarFill.Name = "Fill"
	_bossBarFill.Size = UDim2.new(1, -4, 1, -4)
	_bossBarFill.Position = UDim2.new(0, 2, 0, 2)
	_bossBarFill.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
	_bossBarFill.BorderSizePixel = 0
	_bossBarFill.ZIndex = 81
	_bossBarFill.Parent = _bossBarFrame

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = _bossBarFill

	_bossBarTitle = createLabel(_bossBarFrame, {
		Name = "BossTitle",
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 0, -22),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "THE ONSLAUGHT",
		TextSize = 18,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(200, 100, 255),
		ZIndex = 81,
	})
end

function HUDController:UpdateBossHealth(healthPct: number, enraged: boolean)
	if not _bossBarFrame then
		return
	end

	_bossBarFrame.Visible = true
	_bossBarFill.Size = UDim2.new(math.clamp(healthPct, 0, 1) - 0.005, -4, 1, -4)

	if enraged then
		-- Red pulse effect
		local pulse = math.sin(tick() * 6) * 0.15
		_bossBarFill.BackgroundColor3 = Color3.fromRGB(255, math.floor(30 + pulse * 100), 30)
		_bossBarTitle.TextColor3 = Color3.fromRGB(255, 60, 60)
	else
		_bossBarFill.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
	end

	if healthPct <= 0 then
		task.delay(2, function()
			if _bossBarFrame then
				_bossBarFrame.Visible = false
			end
		end)
	end
end

-------------------------------------------------
-- WEAPON UNLOCK NOTIFICATION
-------------------------------------------------

function HUDController:ShowWeaponUnlocked(weaponName: string)
	local notif = createLabel(_screenGui, {
		Name = "UnlockNotif",
		Size = UDim2.new(0, 400, 0, 50),
		Position = UDim2.new(0.5, -200, 0.15, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = `NEW WEAPON UNLOCKED: {weaponName}!`,
		TextSize = 24,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(255, 220, 50),
		TextStrokeTransparency = 0.3,
		ZIndex = 95,
	})

	task.delay(3, function()
		if notif and notif.Parent then
			notif:Destroy()
		end
	end)
end

-------------------------------------------------
-- STATS UPDATE
-------------------------------------------------

function HUDController:UpdateStats(stats: any)
	if not stats then
		return
	end

	if stats.Health <= 0 then
		_cardFrame.Visible = false
	end

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

	local xpCfg = GameConfig.XP
	local xpNeeded = xpCfg.BaseXPToLevel * (xpCfg.XPScaling ^ (stats.Level - 1))
	local xpPct = stats.XP / xpNeeded
	_xpFill.Size = UDim2.new(math.clamp(xpPct, 0, 1), 0, 1, 0)
	_xpText.Text = `XP: {stats.XP} / {math.floor(xpNeeded)}`

	_levelText.Text = `Level {stats.Level}`
	_killsText.Text = `Kills: {stats.Kills}`

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
	local StatsService = Knit.GetService("StatsService")

	-- Get initial stats
	task.spawn(function()
		local ok, stats = GameService:GetPlayerStats():await()
		if ok and stats then
			self:UpdateStats(stats)
		end
	end)

	-- Load initial soul count
	task.spawn(function()
		local ok, souls = StatsService:GetSouls():await()
		if ok and souls then
			_soulsText.Text = `Souls: {souls}`
		end
	end)

	GameService.PlayerStatsChanged:Connect(function(stats: any)
		self:UpdateStats(stats)
	end)

	GameService.GameStateChanged:Connect(function(state: string, wave: number)
		if state == "Wave" then
			_cardFrame.Visible = false
			_gameOverFrame.Visible = false
			_lobbyFrame.Visible = false
			self:ShowStateMessage(`Wave {wave}`, 2)
			_waveText.Text = `Wave {wave}`
		elseif state == "Intermission" then
			self:ShowStateMessage("Wave cleared!", 2)
		elseif state == "GameOver" then
			_cardFrame.Visible = false
			if _bossBarFrame then
				_bossBarFrame.Visible = false
			end
			self:ShowStateMessage("GAME OVER", 3)
		elseif state == "Victory" then
			_cardFrame.Visible = false
			if _bossBarFrame then
				_bossBarFrame.Visible = false
			end
			self:ShowStateMessage("VICTORY!", 3)
		elseif state == "Lobby" then
			_gameOverFrame.Visible = false
			self:_showLobby()
		elseif state == "WaitingForPlayers" then
			_gameOverFrame.Visible = false
			_lobbyFrame.Visible = false
		end
	end)

	GameService.WaveChanged:Connect(function(wave: number, enemyCount: number)
		_waveText.Text = `Wave {wave} - {enemyCount} enemies`
	end)

	GameService.IntermissionTick:Connect(function(seconds: number)
		_stateText.Text = `Next wave in {seconds}...`
		_stateText.TextTransparency = 0
	end)

	GameService.PlayerDamaged:Connect(function(_damage: number)
		self:_showDamageVignette()
	end)

	GameService.ShowUpgradeCards:Connect(function(cards: any)
		self:ShowUpgradeCards(cards)
	end)

	GameService.GameTimerTick:Connect(function(elapsed: number)
		_timerText.Text = formatTime(elapsed)
	end)

	GameService.GameOverData:Connect(function(data: any)
		self:ShowGameOver(data)
	end)

	GameService.RespawnCountdown:Connect(function(secondsLeft: number)
		self:ShowStateMessage(`Respawning in {secondsLeft}...`)
		if secondsLeft <= 1 then
			task.delay(1, function()
				if _stateText.Text == "Respawning in 1..." then
					_stateText.TextTransparency = 1
				end
			end)
		end
	end)

	-- Souls earned notification
	StatsService.SoulsEarned:Connect(function(earned: number, total: number)
		_soulsText.Text = `Souls: {total}`
		-- Update game over screen with souls earned
		if _gameOverFrame and _gameOverFrame.Visible then
			local soulsEarnedLabel = _gameOverFrame:FindFirstChild("SoulsEarned") :: TextLabel?
			if soulsEarnedLabel then
				soulsEarnedLabel.Text = `+{earned} Souls`
			end
		end
	end)

	-- Weapon unlock notification
	StatsService.WeaponUnlocked:Connect(function(weaponName: string)
		self:ShowWeaponUnlocked(weaponName)
	end)

	-- Boss health bar
	local EnemyService = Knit.GetService("EnemyService")
	EnemyService.BossHealthUpdate:Connect(function(healthPct: number, enraged: boolean)
		self:UpdateBossHealth(healthPct, enraged)
	end)

	-- Power-up buff indicators
	local PowerUpService = Knit.GetService("PowerUpService")

	PowerUpService.BuffStarted:Connect(function(buffType: string, duration: number)
		self:ShowBuff(buffType, duration)
	end)

	PowerUpService.BuffEnded:Connect(function(buffType: string)
		self:RemoveBuff(buffType)
	end)

	-- Chest HUD indicator
	PowerUpService.ChestSpawned:Connect(function(_position: Vector3)
		self:ShowStateMessage("Void Chest spawned!", 3)
	end)

	-- Update buff timers
	RunService.RenderStepped:Connect(function(_dt)
		self:_updateBuffTimers()
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
