--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local InDepthAgentDebugPanel = require(script.Parent.Components.InDepthAgentDebugPanel)

local function App()
	return React.createElement(React.Fragment, nil, {
		CompyAgentDebugUI = React.createElement("ScreenGui", {
			DisplayOrder = 100,
			IgnoreGuiInset = true,
			ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		}, {
			InDepthAgentDebugPanel = React.createElement(InDepthAgentDebugPanel),
		}),
	})
end

return App
