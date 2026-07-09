--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local Config = require(ReplicatedStorage.CompyAgent.Config)
local Theme = require(script.Parent.Theme)

local player = Players.LocalPlayer
local playerScripts = player:WaitForChild("PlayerScripts")
local CompyClientScripts = playerScripts:WaitForChild("CompyAgent")
local DebugRemoteEvents = require(CompyClientScripts.Remotes.DebugRemoteEvents)
local DebugRemoteFunctions = require(CompyClientScripts.Remotes.DebugRemoteFunctions)

local NO_AGENT_ID = ""
local PANEL_WIDTH_SCALE = 0.33
local PANEL_HORIZONTAL_PADDING = 40
local LOG_HORIZONTAL_PADDING = 24
local LOG_TEXT_SIZE = 14
local LOG_CANVAS_VERTICAL_PADDING = 24
local LOG_SCROLLBAR_WIDTH = 12

local function getAgentModelFolder(): Folder?
	local folder = Workspace:FindFirstChild(Config.Agent.ModelFolderName)
	if folder and folder:IsA("Folder") then
		return folder
	end

	return nil
end

local function getAgentIdFromTarget(target: BasePart?): string?
	if not target then
		return nil
	end

	local model = target:FindFirstAncestorOfClass("Model")
	if not model or not model:FindFirstChildOfClass("Humanoid") then
		return nil
	end

	local folder = getAgentModelFolder()
	if not folder or not model:IsDescendantOf(folder) then
		return nil
	end

	return model.Name
end

local function isPointerInsidePanel(mouseX: number): boolean
	local camera = Workspace.CurrentCamera
	if not camera then
		return false
	end

	return mouseX >= camera.ViewportSize.X * 0.5
end

local function getLogTextWidth(): number
	local camera = Workspace.CurrentCamera
	local viewportWidth = if camera then camera.ViewportSize.X else 1200
	local panelWidth = viewportWidth * PANEL_WIDTH_SCALE
	return math.max(180, panelWidth - PANEL_HORIZONTAL_PADDING - LOG_HORIZONTAL_PADDING - LOG_SCROLLBAR_WIDTH)
end

local function getLogCanvasHeight(logText: string): number
	local measuredTextSize = TextService:GetTextSize(
		logText,
		LOG_TEXT_SIZE,
		Enum.Font.Code,
		Vector2.new(getLogTextWidth(), math.huge)
	)

	return math.ceil(measuredTextSize.Y + LOG_CANVAS_VERTICAL_PADDING)
end

local function selectTextBoxContents(textBox: TextBox): ()
	task.defer(function(): ()
		if not textBox.Parent then
			return
		end

		textBox:CaptureFocus()
		textBox.CursorPosition = 1
		textBox.SelectionStart = #textBox.Text + 1
	end)
end

local function InDepthAgentDebugPanel()
	local selectedAgentId, setSelectedAgentId = React.useState(NO_AGENT_ID)
	local debugText, setDebugText = React.useState("")

	local function closePanel(): ()
		if selectedAgentId == NO_AGENT_ID then
			return
		end

		DebugRemoteEvents.fireAgentInDepthDebugActiveChanged(selectedAgentId, false)
		setSelectedAgentId(NO_AGENT_ID)
		setDebugText("")
	end

	React.useEffect(function()
		local mouse = player:GetMouse()
		local clickConnection = mouse.Button1Down:Connect(function(): ()
			if selectedAgentId ~= NO_AGENT_ID and isPointerInsidePanel(mouse.X) then
				return
			end

			local agentId = getAgentIdFromTarget(mouse.Target)
			if not agentId then
				return
			end

			if selectedAgentId == agentId then
				DebugRemoteEvents.fireAgentInDepthDebugActiveChanged(agentId, false)
				setSelectedAgentId(NO_AGENT_ID)
				setDebugText("")
				return
			end

			if selectedAgentId ~= NO_AGENT_ID then
				DebugRemoteEvents.fireAgentInDepthDebugActiveChanged(selectedAgentId, false)
			end

			DebugRemoteEvents.fireAgentInDepthDebugActiveChanged(agentId, true)
			setSelectedAgentId(agentId)
			setDebugText("")
		end)

		return function(): ()
			clickConnection:Disconnect()
		end
	end, { selectedAgentId })

	React.useEffect(function()
		if selectedAgentId == NO_AGENT_ID then
			setDebugText("")
			return function(): () end
		end

		local isMounted = true
		local latestRequestId = 0
		local latestAppliedRequestId = 0

		local function requestDebugText(): ()
			latestRequestId += 1
			local requestId = latestRequestId

			task.spawn(function(): ()
				local nextDebugText = DebugRemoteFunctions.getAgentInDepthDebugText(selectedAgentId)

				if isMounted and requestId > latestAppliedRequestId then
					latestAppliedRequestId = requestId
					setDebugText(nextDebugText)
				end
			end)
		end

		requestDebugText()

		local heartbeatConnection = RunService.Heartbeat:Connect(function(): ()
			requestDebugText()
		end)

		return function(): ()
			isMounted = false
			heartbeatConnection:Disconnect()
		end
	end, { selectedAgentId })

	if selectedAgentId == NO_AGENT_ID then
		return React.createElement(React.Fragment)
	end

	local liveDebugText = if debugText == "" then "No debug log lines." else debugText
	local displayDebugText = liveDebugText
	local logCanvasHeight = getLogCanvasHeight(displayDebugText)

	local function focusLogText(textBox: TextBox): ()
		selectTextBoxContents(textBox)
	end

	return React.createElement(React.Fragment, nil, {
		InDepthAgentDebugPanel = React.createElement("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = Theme.panelBackground,
			BackgroundTransparency = 0.02,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromScale(PANEL_WIDTH_SCALE, 1),
		}, {
			Stroke = React.createElement("UIStroke", {
				Color = Theme.panelStroke,
				Thickness = 1,
				Transparency = 0.15,
			}),
			Padding = React.createElement("UIPadding", {
				PaddingBottom = UDim.new(0, 18),
				PaddingLeft = UDim.new(0, 20),
				PaddingRight = UDim.new(0, 20),
				PaddingTop = UDim.new(0, 18),
			}),
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 12),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Header = React.createElement("Frame", {
				BackgroundTransparency = 1,
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 58),
			}, {
				Title = React.createElement("TextLabel", {
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamBold,
					Position = UDim2.fromOffset(0, 0),
					Size = UDim2.new(1, -44, 0, 30),
					Text = "Agent Debug Log",
					TextColor3 = Theme.textPrimary,
					TextSize = 20,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				AgentId = React.createElement("TextLabel", {
					BackgroundTransparency = 1,
					Font = Enum.Font.Code,
					Position = UDim2.fromOffset(0, 32),
					Size = UDim2.new(1, -44, 0, 22),
					Text = selectedAgentId,
					TextColor3 = Theme.textMuted,
					TextSize = 14,
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				CloseButton = React.createElement("TextButton", {
					AnchorPoint = Vector2.new(1, 0),
					AutoButtonColor = true,
					BackgroundColor3 = Theme.buttonBackground,
					BorderSizePixel = 0,
					Font = Enum.Font.GothamBold,
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromOffset(34, 34),
					Text = "X",
					TextColor3 = Theme.textPrimary,
					TextSize = 14,
					[React.Event.Activated] = closePanel,
				}, {
					Corner = React.createElement("UICorner", {
						CornerRadius = UDim.new(0, 4),
					}),
					Stroke = React.createElement("UIStroke", {
						Color = Theme.buttonStroke,
						Thickness = 1,
						Transparency = 0.2,
					}),
				}),
			}),
			LogScroller = React.createElement("ScrollingFrame", {
				Active = true,
				BackgroundColor3 = Theme.buttonBackground,
				BackgroundTransparency = 0.15,
				BorderSizePixel = 0,
				CanvasSize = UDim2.fromOffset(0, logCanvasHeight),
				LayoutOrder = 2,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ScrollBarImageColor3 = Theme.textMuted,
				ScrollBarImageTransparency = 0.15,
				ScrollBarThickness = 6,
				Size = UDim2.new(1, 0, 1, -70),
				VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
			}, {
				Corner = React.createElement("UICorner", {
					CornerRadius = UDim.new(0, 6),
				}),
				Stroke = React.createElement("UIStroke", {
					Color = Theme.buttonStroke,
					Thickness = 1,
					Transparency = 0.35,
				}),
				Padding = React.createElement("UIPadding", {
					PaddingBottom = UDim.new(0, 12),
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 12),
					PaddingTop = UDim.new(0, 12),
				}),
				Layout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				LogText = React.createElement("TextBox", {
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					ClearTextOnFocus = false,
					Font = Enum.Font.Code,
					LayoutOrder = 1,
					MultiLine = true,
					Size = UDim2.fromScale(1, 0),
					Text = displayDebugText,
					TextColor3 = Theme.textPrimary,
					TextEditable = false,
					TextSize = LOG_TEXT_SIZE,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					[React.Event.Focused] = focusLogText,
					[React.Event.InputBegan] = function(textBox: TextBox, input: InputObject): ()
						if input.UserInputType == Enum.UserInputType.MouseButton1 then
							focusLogText(textBox)
						end
					end,
				}),
			}),
		}),
	})
end

return InDepthAgentDebugPanel
