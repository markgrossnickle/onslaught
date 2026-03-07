--!strict
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local Player = Players.LocalPlayer

local AchievementController = Knit.CreateController({
	Name = "AchievementController",
})

local _popupQueue: { { Id: string, Name: string, Description: string, Reward: number } } = {}
local _showingPopup = false

function AchievementController:_showNextPopup()
	if _showingPopup or #_popupQueue == 0 then
		return
	end

	_showingPopup = true
	local data = table.remove(_popupQueue, 1)
	if not data then
		_showingPopup = false
		return
	end

	local playerGui = Player:WaitForChild("PlayerGui")
	local hudGui = playerGui:FindFirstChild("OnslaughtHUD") :: ScreenGui?
	if not hudGui then
		_showingPopup = false
		return
	end

	-- Create popup frame
	local popup = Instance.new("Frame")
	popup.Name = "AchievementPopup"
	popup.Size = UDim2.new(0, 300, 0, 70)
	popup.Position = UDim2.new(0.5, -150, 0, -80) -- start offscreen
	popup.BackgroundColor3 = Color3.fromRGB(20, 15, 30)
	popup.BorderSizePixel = 0
	popup.ZIndex = 90
	popup.Parent = hudGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = popup

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 200, 60)
	stroke.Thickness = 2
	stroke.Parent = popup

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -20, 0, 25)
	title.Position = UDim2.new(0, 10, 0, 8)
	title.BackgroundTransparency = 1
	title.Text = "Achievement Unlocked!"
	title.TextColor3 = Color3.fromRGB(255, 200, 60)
	title.TextSize = 14
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 91
	title.Parent = popup

	local name = Instance.new("TextLabel")
	name.Name = "AchievementName"
	name.Size = UDim2.new(1, -20, 0, 20)
	name.Position = UDim2.new(0, 10, 0, 30)
	name.BackgroundTransparency = 1
	name.Text = data.Name
	name.TextColor3 = Color3.fromRGB(255, 255, 255)
	name.TextSize = 16
	name.Font = Enum.Font.GothamBold
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.ZIndex = 91
	name.Parent = popup

	local desc = Instance.new("TextLabel")
	desc.Name = "Description"
	desc.Size = UDim2.new(0.7, -10, 0, 15)
	desc.Position = UDim2.new(0, 10, 0, 50)
	desc.BackgroundTransparency = 1
	desc.Text = data.Description
	desc.TextColor3 = Color3.fromRGB(180, 180, 200)
	desc.TextSize = 12
	desc.Font = Enum.Font.Gotham
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.ZIndex = 91
	desc.Parent = popup

	if data.Reward > 0 then
		local reward = Instance.new("TextLabel")
		reward.Name = "Reward"
		reward.Size = UDim2.new(0.3, -10, 0, 15)
		reward.Position = UDim2.new(0.7, 0, 0, 50)
		reward.BackgroundTransparency = 1
		reward.Text = "+" .. data.Reward .. " Souls"
		reward.TextColor3 = Color3.fromRGB(120, 200, 255)
		reward.TextSize = 12
		reward.Font = Enum.Font.GothamBold
		reward.TextXAlignment = Enum.TextXAlignment.Right
		reward.ZIndex = 91
		reward.Parent = popup
	end

	-- Slide in
	TweenService:Create(popup, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -150, 0, 20),
	}):Play()

	-- Wait and slide out
	task.delay(3, function()
		TweenService:Create(popup, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, -150, 0, -80),
		}):Play()

		task.delay(0.35, function()
			popup:Destroy()
			_showingPopup = false
			self:_showNextPopup()
		end)
	end)
end

function AchievementController:KnitInit() end

function AchievementController:KnitStart()
	local AchievementService = Knit.GetService("AchievementService")

	AchievementService.AchievementUnlocked:Connect(
		function(achievementId: string, achievementName: string, description: string, reward: number)
			table.insert(_popupQueue, {
				Id = achievementId,
				Name = achievementName,
				Description = description,
				Reward = reward,
			})
			self:_showNextPopup()
		end
	)
end

return AchievementController
