--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local AverageFrameTooltip = require(script.Parent.Components.AverageFrameTooltip)
local SpeedControlPanel = require(script.Parent.Components.SpeedControlPanel)

local function App()
	return React.createElement(React.Fragment, nil, {
		CompyAgentDebugUI = React.createElement("ScreenGui", {
			DisplayOrder = 100,
			IgnoreGuiInset = true,
			ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		}, {
			AverageFrameTooltip = React.createElement(AverageFrameTooltip),
			SpeedControlPanel = React.createElement(SpeedControlPanel),
		}),
	})
end

return App
