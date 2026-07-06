--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Theme)

local playerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
local CompyClientScripts = playerScripts:WaitForChild("CompyAgent")
local DebugRemoteFunctions = require(CompyClientScripts.Remotes.DebugRemoteFunctions)

local PENDING_AVERAGE_FRAME_MS = -1

local function formatAverageFrameMS(averageFrameMS: number): string
	if averageFrameMS < 0 then
		return "--"
	end

	return string.format("%d ms", averageFrameMS)
end

local function AverageFrameTooltip()
	local averageFrameMS, setAverageFrameMS = React.useState(PENDING_AVERAGE_FRAME_MS)

	React.useEffect(function()
		local isMounted = true
		local latestRequestId = 0
		local latestAppliedRequestId = 0

		local function requestAverageFrameMS(): ()
			latestRequestId += 1
			local requestId = latestRequestId

			task.spawn(function(): ()
				local nextAverageFrameMS = DebugRemoteFunctions.getAverageFrameMS()

				if isMounted and requestId > latestAppliedRequestId then
					latestAppliedRequestId = requestId
					setAverageFrameMS(nextAverageFrameMS or PENDING_AVERAGE_FRAME_MS)
				end
			end)
		end

		requestAverageFrameMS()

		local heartbeatConnection = RunService.Heartbeat:Connect(function(): ()
			requestAverageFrameMS()
		end)

		return function(): ()
			isMounted = false
			heartbeatConnection:Disconnect()
		end
	end, {})

	return React.createElement(React.Fragment, nil, {
		AverageFrameTooltip = React.createElement("Frame", {
			BackgroundColor3 = Theme.panelBackground,
			BackgroundTransparency = 0.06,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(250, 12),
			Size = UDim2.fromOffset(180, 30),
		}, {
			Corner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
			Stroke = React.createElement("UIStroke", {
				Color = Theme.panelStroke,
				Thickness = 1,
				Transparency = 0.25,
			}),
			Padding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 9),
				PaddingRight = UDim.new(0, 9),
			}),
			Label = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				Size = UDim2.fromScale(1, 1),
				Text = "averageFrameMS: " .. formatAverageFrameMS(averageFrameMS),
				TextColor3 = Theme.textPrimary,
				TextSize = 12,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		}),
	})
end

return AverageFrameTooltip
