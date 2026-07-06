--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local IconButton = require(script.Parent.IconButton)
local Theme = require(script.Parent.Theme)

local playerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
local CompyClientScripts = playerScripts:WaitForChild("CompyAgent")
local DebugRemoteEvents = require(CompyClientScripts.Remotes.DebugRemoteEvents)

local SPEED_STEPS = { 0.0625, 0.125, 0.25, 0.5, 1, 2, 4, 8, 16 }
local DEFAULT_SPEED_INDEX = 5

local function clampSpeedIndex(speedIndex: number): number
	return math.clamp(speedIndex, 1, #SPEED_STEPS)
end

local function formatSpeed(speedScale: number): string
	if speedScale % 1 == 0 then
		return `{speedScale}x`
	end

	return string.format("%.2gx", speedScale)
end

local function SpeedControlPanel()
	local isPaused, setIsPaused = React.useState(false)
	local speedIndex, setSpeedIndex = React.useState(DEFAULT_SPEED_INDEX)
	local speedScale = SPEED_STEPS[speedIndex]

	local function togglePlayback(): ()
		local nextIsPaused = not isPaused
		setIsPaused(nextIsPaused)
		DebugRemoteEvents.firePlaybackToggled(nextIsPaused)
	end

	local function slowDown(): ()
		local nextSpeedIndex = clampSpeedIndex(speedIndex - 1)
		setSpeedIndex(nextSpeedIndex)
		DebugRemoteEvents.fireSpeedDecreased(SPEED_STEPS[nextSpeedIndex])
	end

	local function speedUp(): ()
		local nextSpeedIndex = clampSpeedIndex(speedIndex + 1)
		setSpeedIndex(nextSpeedIndex)
		DebugRemoteEvents.fireSpeedIncreased(SPEED_STEPS[nextSpeedIndex])
	end

	return React.createElement(React.Fragment, nil, {
		SpeedControlPanel = React.createElement("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = Theme.panelBackground,
			BackgroundTransparency = 0.06,
			BorderSizePixel = 0,
			Position = UDim2.new(1, -12, 0, 12),
			Size = UDim2.fromOffset(164, 38),
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
				PaddingBottom = UDim.new(0, 5),
				PaddingLeft = UDim.new(0, 5),
				PaddingRight = UDim.new(0, 5),
				PaddingTop = UDim.new(0, 5),
			}),
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			PlaybackButton = React.createElement(IconButton, {
				name = "PlaybackButton",
				text = if isPaused then ">" else "||",
				layoutOrder = 1,
				onActivated = togglePlayback,
				tooltipText = if isPaused then "Resume simulation" else "Pause simulation",
				width = 30,
				isActive = isPaused,
			}),
			SlowButton = React.createElement(IconButton, {
				name = "SlowButton",
				text = "-",
				layoutOrder = 2,
				onActivated = slowDown,
				tooltipText = "Slow simulation",
				width = 30,
				isDisabled = speedIndex == 1,
			}),
			SpeedLabel = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				LayoutOrder = 3,
				Size = UDim2.fromOffset(54, 28),
				Text = formatSpeed(speedScale),
				TextColor3 = Theme.textPrimary,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
			FastButton = React.createElement(IconButton, {
				name = "FastButton",
				text = "+",
				layoutOrder = 4,
				onActivated = speedUp,
				tooltipText = "Speed up simulation",
				width = 30,
				isDisabled = speedIndex == #SPEED_STEPS,
			}),
		}),
	})
end

return SpeedControlPanel
