local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local CompyServerScripts = ServerScriptService.CompyAgent

local Types = require(CompyServerScripts.Core.Types)

local VisualizationService = {}
VisualizationService.__index = VisualizationService

local BILLBOARD_NAME = "CompyDebugBillboard"
local DEBUG_FOLDER_NAME = "CompyAgentDebug"
local RAYCAST_LINE_THICKNESS = 0.04
local TRACER_LINE_THICKNESS = 0.06
local RAYCAST_DEBUG_DURATION = 0.4
local TRACER_DEBUG_DURATION = 0.2
local RAYCAST_COLOR = Color3.fromRGB(0, 255, 80)
local TRACER_COLOR = Color3.fromRGB(255, 255, 255)

local function ensureBillboard(state: Types.AgentState): TextLabel?
	local head = state.head
	if not head then
		return nil
	end

	local billboard = head:FindFirstChild(BILLBOARD_NAME)
	if not billboard then
		billboard = Instance.new("BillboardGui")
		billboard.Name = BILLBOARD_NAME
		billboard.Size = UDim2.fromOffset(180, 64)
		billboard.StudsOffset = Vector3.new(0, 2, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = head

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 0.3
		label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextScaled = true
		label.Font = Enum.Font.Code
		label.Parent = billboard
	end

	local label = billboard:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		return label
	end

	return nil
end

local function removeBillboard(state: Types.AgentState): ()
	local head = state.head
	if not head then
		return
	end

	local billboard = head:FindFirstChild(BILLBOARD_NAME)
	if billboard then
		billboard:Destroy()
	end
end

local function drawLine(
	part: BasePart,
	startPosition: Vector3,
	endPosition: Vector3,
	thickness: number,
	color: Color3
): ()
	local offset = endPosition - startPosition
	if offset.Magnitude <= 0.001 then
		part.Transparency = 1
		return
	end

	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = Vector3.new(thickness, thickness, offset.Magnitude)
	part.CFrame = CFrame.lookAt(startPosition:Lerp(endPosition, 0.5), endPosition)
	part.Transparency = 0
end

local function removeLine(lines: { [string]: BasePart }, key: string): ()
	local line = lines[key]
	if not line then
		return
	end

	line:Destroy()
	lines[key] = nil
end

function VisualizationService:_getDebugFolder(): Folder
	if self.debugFolder and self.debugFolder.Parent then
		return self.debugFolder
	end

	local existing = Workspace:FindFirstChild(DEBUG_FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		self.debugFolder = existing
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = DEBUG_FOLDER_NAME
	folder.Parent = Workspace
	self.debugFolder = folder

	return folder
end

function VisualizationService:_getLine(lines: { [string]: BasePart }, key: string, name: string): BasePart
	local line = lines[key]
	if line and line.Parent then
		return line
	end

	line = Instance.new("Part")
	line.Name = name
	line.Parent = self:_getDebugFolder()
	lines[key] = line

	return line
end

function VisualizationService:_updateInfoBar(state: Types.AgentState): ()
	if not self.config.Agent.InfoBar then
		removeBillboard(state)
		return
	end

	local label = ensureBillboard(state)
	if label then
		label.Text = ("%s\n%s / %s\nHP %d Ammo %d"):format(
			state.id,
			state.debugGoal,
			state.debugAction,
			state.health,
			state.ammo
		)
	end
end

function VisualizationService:_updateRaycast(state: Types.AgentState, now: number): ()
	if
		not self.config.Agent.DebugRaycast
		or not state.lastRaycastOrigin
		or not state.lastRaycastEnd
		or now - state.lastRaycastAt > RAYCAST_DEBUG_DURATION
	then
		removeLine(self.raycastLines, state.id)
		return
	end

	local line = self:_getLine(self.raycastLines, state.id, "Raycast_" .. state.id)
	drawLine(line, state.lastRaycastOrigin, state.lastRaycastEnd, RAYCAST_LINE_THICKNESS, RAYCAST_COLOR)
end

function VisualizationService:_updateTracer(state: Types.AgentState, now: number): ()
	if
		not self.config.Agent.DebugTracers
		or not state.lastShotOrigin
		or not state.lastShotTarget
		or now - state.lastShotAt > TRACER_DEBUG_DURATION
	then
		removeLine(self.tracerLines, state.id)
		return
	end

	local line = self:_getLine(self.tracerLines, state.id, "Tracer_" .. state.id)
	drawLine(line, state.lastShotOrigin, state.lastShotTarget, TRACER_LINE_THICKNESS, TRACER_COLOR)
end

function VisualizationService:_update(): ()
	local now = os.clock()
	for _, runtime in ipairs(self.agentService:GetAllRuntimes()) do
		local state = runtime.state

		self:_updateInfoBar(state)
		self:_updateRaycast(state, now)
		self:_updateTracer(state, now)
	end
end

function VisualizationService:_clearDebugLines(): ()
	for key in pairs(self.raycastLines) do
		removeLine(self.raycastLines, key)
	end

	for key in pairs(self.tracerLines) do
		removeLine(self.tracerLines, key)
	end
end

function VisualizationService:Start(): ()
	if self.running then
		return
	end

	self.running = true
	self.thread = task.spawn(function(): ()
		while self.running do
			self:_update()
			task.wait(self.config.Simulation.VisualizationInterval)
		end
	end)
end

function VisualizationService:Stop(): ()
	self.running = false
	self:_clearDebugLines()
end

function VisualizationService.new(config: Types.Config, agentService: Types.AgentService): Types.VisualizationService
	local self = setmetatable({}, VisualizationService)
	self.config = config
	self.agentService = agentService
	self.running = false
	self.thread = nil
	self.debugFolder = nil
	self.raycastLines = {}
	self.tracerLines = {}
	return self
end

return VisualizationService
