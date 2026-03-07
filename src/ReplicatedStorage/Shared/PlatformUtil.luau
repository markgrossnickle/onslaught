--!strict
--[=[
	@module PlatformUtil
	Platform detection for mobile, console, and PC.
	Safe to require from server (returns PC defaults).
]=]
local RunService = game:GetService("RunService")

local PlatformUtil = {}

export type Platform = "Mobile" | "Console" | "PC"

local _detected: Platform? = nil
local _hasGamepad: boolean? = nil

function PlatformUtil.Detect(): Platform
	if _detected then
		return _detected
	end

	if RunService:IsServer() then
		_detected = "PC"
		return _detected
	end

	local UserInputService = game:GetService("UserInputService")
	local GuiService = game:GetService("GuiService")

	if GuiService:IsTenFootInterface() then
		_detected = "Console"
	elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		_detected = "Mobile"
	else
		_detected = "PC"
	end

	return _detected
end

function PlatformUtil.IsMobile(): boolean
	return PlatformUtil.Detect() == "Mobile"
end

function PlatformUtil.IsConsole(): boolean
	return PlatformUtil.Detect() == "Console"
end

function PlatformUtil.IsPC(): boolean
	return PlatformUtil.Detect() == "PC"
end

function PlatformUtil.HasGamepad(): boolean
	if _hasGamepad ~= nil then
		return _hasGamepad
	end
	if RunService:IsServer() then
		_hasGamepad = false
		return false
	end
	local UserInputService = game:GetService("UserInputService")
	_hasGamepad = UserInputService.GamepadEnabled
	return _hasGamepad
end

function PlatformUtil.TextScale(): number
	if PlatformUtil.IsConsole() then
		return 1.2
	end
	return 1.0
end

return table.freeze(PlatformUtil)
