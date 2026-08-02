--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local CompyServerScripts = ServerScriptService.CompyAgent
local CompySharedScripts = ReplicatedStorage.CompyAgent

local AgentService = require(CompyServerScripts.Services.AgentService)
local _DefaultConfig = require(CompySharedScripts.Config)

local VisualizationService = {}
VisualizationService.__index = VisualizationService

local BILLBOARD_NAME = "CompyDebugBillboard"
local DEBUG_FOLDER_NAME = "CompyAgentDebug"
local RAYCAST_COLOR = Color3.fromRGB(0, 255, 80)
local TRACER_COLOR = Color3.fromRGB(255, 255, 255)

type VisualizationServiceData = {
	config: typeof(_DefaultConfig),
	agentService: AgentService.AgentService,
	running: boolean,
	thread: thread?,
	debugFolder: Folder?,
	raycastLines: { [number]: BasePart },
	tracerLines: { [number]: BasePart },
	raycastEvents: {
		[number]: { startPosition: Vector3, endPosition: Vector3, recordedAt: number },
	},
	tracerEvents: {
		[number]: { startPosition: Vector3, endPosition: Vector3, recordedAt: number },
	},
}

export type VisualizationService = typeof(setmetatable({} :: VisualizationServiceData, VisualizationService))

local function getHead(character: Model): BasePart?
	local head = character:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head else nil
end

local function ensureLabel(character: Model): TextLabel?
	local head = getHead(character)
	if not head then
		return nil
	end

	local billboard = head:FindFirstChild(BILLBOARD_NAME)
	if not billboard then
		local newBillboard = Instance.new("BillboardGui")
		newBillboard.Name = BILLBOARD_NAME
		newBillboard.Size = UDim2.fromOffset(180, 64)
		newBillboard.StudsOffset = Vector3.new(0, 2, 0)
		newBillboard.AlwaysOnTop = true
		newBillboard.Parent = head

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 0.3
		label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextScaled = true
		label.Font = Enum.Font.Code
		label.Parent = newBillboard
		return label
	end

	local label = billboard:FindFirstChild("Label")
	return if label and label:IsA("TextLabel") then label else nil
end

local function removeBillboard(character: Model): ()
	local head = getHead(character)
	local billboard = if head then head:FindFirstChild(BILLBOARD_NAME) else nil
	if billboard then
		billboard:Destroy()
	end
end

local function drawLine(part: BasePart, fromPosition: Vector3, toPosition: Vector3, thickness: number, color: Color3): ()
	local offset = toPosition - fromPosition
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
	part.CFrame = CFrame.lookAt(fromPosition:Lerp(toPosition, 0.5), toPosition)
	part.Transparency = 0
end

function VisualizationService.GetDebugFolder(self: VisualizationService): Folder
	if self.debugFolder and self.debugFolder.Parent then
		return self.debugFolder
	end
	local folder = Instance.new("Folder")
	folder.Name = DEBUG_FOLDER_NAME
	folder.Parent = Workspace
	self.debugFolder = folder
	return folder
end

function VisualizationService.GetLine(
	self: VisualizationService,
	lines: { [number]: BasePart },
	agentId: number,
	prefix: string
): BasePart
	local line = lines[agentId]
	if line and line.Parent then
		return line
	end
	local newLine = Instance.new("Part")
	newLine.Name = `{prefix}_{agentId}`
	newLine.Parent = self:GetDebugFolder()
	lines[agentId] = newLine
	return newLine
end

function VisualizationService.RecordRaycast(
	self: VisualizationService,
	agentId: number,
	startPosition: Vector3,
	endPosition: Vector3
): ()
	self.raycastEvents[agentId] = {
		startPosition = startPosition,
		endPosition = endPosition,
		recordedAt = os.clock(),
	}
end

function VisualizationService.RecordTracer(
	self: VisualizationService,
	agentId: number,
	startPosition: Vector3,
	endPosition: Vector3
): ()
	self.tracerEvents[agentId] = {
		startPosition = startPosition,
		endPosition = endPosition,
		recordedAt = os.clock(),
	}
end

function VisualizationService.Update(self: VisualizationService): ()
	local now = os.clock()
	for _, record in ipairs(self.agentService:GetAllRecords()) do
		if self.config.Agent.InfoBar then
			local label = ensureLabel(record.character)
			if label then
				local goal = record.agent.plannerState.goal
				local action = record.agent.plannerState.goapAction
				label.Text = ("%s [%s]\n%s / %s\nHP %.0f Ammo %d"):format(
					record.name,
					record.teamId,
					if goal then goal.id else "None",
					if action then action.id else "None",
					record.agent.health,
					record.agent.rifleAmmo
				)
			end
		else
			removeBillboard(record.character)
		end

		local raycast = self.raycastEvents[record.id]
		if self.config.Agent.DebugRaycast and raycast and now - raycast.recordedAt <= 0.4 then
			drawLine(self:GetLine(self.raycastLines, record.id, "Raycast"), raycast.startPosition, raycast.endPosition, 0.04, RAYCAST_COLOR)
		elseif self.raycastLines[record.id] then
			self.raycastLines[record.id]:Destroy()
			self.raycastLines[record.id] = nil
		end

		local tracer = self.tracerEvents[record.id]
		if self.config.Agent.DebugTracers and tracer and now - tracer.recordedAt <= 0.2 then
			drawLine(self:GetLine(self.tracerLines, record.id, "Tracer"), tracer.startPosition, tracer.endPosition, 0.06, TRACER_COLOR)
		elseif self.tracerLines[record.id] then
			self.tracerLines[record.id]:Destroy()
			self.tracerLines[record.id] = nil
		end
	end
end

function VisualizationService.Start(self: VisualizationService): ()
	if self.running then
		return
	end
	self.running = true
	self.thread = task.spawn(function(): ()
		while self.running do
			self:Update()
			task.wait(self.config.Simulation.VisualizationInterval)
		end
	end)
end

function VisualizationService.Stop(self: VisualizationService): ()
	self.running = false
	self.thread = nil
	for _, record in ipairs(self.agentService:GetAllRecords()) do
		removeBillboard(record.character)
	end
	if self.debugFolder then
		self.debugFolder:Destroy()
		self.debugFolder = nil
	end
	table.clear(self.raycastLines)
	table.clear(self.tracerLines)
	table.clear(self.raycastEvents)
	table.clear(self.tracerEvents)
end

function VisualizationService.new(
	config: typeof(_DefaultConfig),
	agentService: AgentService.AgentService
): VisualizationService
	return setmetatable({
		config = config,
		agentService = agentService,
		running = false,
		thread = nil,
		debugFolder = nil,
		raycastLines = {},
		tracerLines = {},
		raycastEvents = {},
		tracerEvents = {},
	}, VisualizationService)
end

return VisualizationService
