--!strict
--[=[
	@class PlatformController
	Applies platform-specific visual adjustments:
	- Mobile: reduced particles, trail lifetimes, reports platform to server
	- Console: no visual reductions, server reporting
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local PlatformUtil = require(ReplicatedStorage.Shared.PlatformUtil)

local PlatformController = Knit.CreateController({
	Name = "PlatformController",
})

local _isMobile = false

local function reduceParticleRates(parent: Instance)
	local mult = GameConfig.Mobile.ParticleRateMult
	local trailMult = GameConfig.Mobile.TrailLifetimeMult

	for _, desc in parent:GetDescendants() do
		if desc:IsA("ParticleEmitter") then
			desc.Rate = math.max(1, math.floor(desc.Rate * mult))
		elseif desc:IsA("Trail") then
			desc.Lifetime = desc.Lifetime * trailMult
		end
	end
end

function PlatformController:KnitInit()
	_isMobile = PlatformUtil.IsMobile()
end

function PlatformController:KnitStart()
	local GameService = Knit.GetService("GameService")

	-- Report platform to server
	local platform = PlatformUtil.Detect()
	GameService:ReportPlatform(platform):catch(function(err)
		warn("ReportPlatform failed:", err)
	end)

	if not _isMobile then
		return
	end

	-- Reduce particles on existing workspace objects
	reduceParticleRates(workspace)

	-- Watch for new instances and reduce their particles
	workspace.DescendantAdded:Connect(function(desc)
		if desc:IsA("ParticleEmitter") then
			local mult = GameConfig.Mobile.ParticleRateMult
			desc.Rate = math.max(1, math.floor(desc.Rate * mult))
		elseif desc:IsA("Trail") then
			desc.Lifetime = desc.Lifetime * GameConfig.Mobile.TrailLifetimeMult
		end
	end)

	-- Reduce death particle counts by skipping every other one
	-- (handled in CombatController via PlatformUtil check)
end

function PlatformController:IsMobile(): boolean
	return _isMobile
end

return PlatformController
