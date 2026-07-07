--[=[
	VisualizationSystem

	Read-only visual subscriber for the data-first simulation. It polls agent
	state at a fixed visual cadence and updates pre-created Roblox Instances.
]=]

local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local VisualizationSystem = {}
VisualizationSystem.__index = VisualizationSystem

local HIDDEN_CFRAME = CFrame.new(0, -10000, 0)
local MIN_LINE_DISTANCE = 0.05

local function configureDebugBasePart(part: BasePart, name: string, size: Vector3, color: Color3): ()
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Size = size
	part.Color = color
	part.Transparency = 1
	part.CFrame = HIDDEN_CFRAME
end

local function configureDebugPart(part: Part, name: string, size: Vector3, color: Color3, shape: Enum.PartType?): ()
	configureDebugBasePart(part, name, size, color)
	if shape then
		part.Shape = shape
	end
end

local function hideDebugPart(part: BasePart?): ()
	if part then
		part.Transparency = 1
		part.CFrame = HIDDEN_CFRAME
	end
end

local function drawDebugLine(
	part: BasePart,
	startPosition: Vector3,
	endPosition: Vector3,
	thickness: number,
	color: Color3,
	transparency: number
): ()
	local offset = endPosition - startPosition
	local distance = offset.Magnitude
	if distance < MIN_LINE_DISTANCE then
		hideDebugPart(part)
		return
	end

	part.Size = Vector3.new(thickness, thickness, distance)
	part.CFrame = CFrame.lookAt(startPosition + offset * 0.5, endPosition)
	part.Color = color
	part.Transparency = transparency
end

local function getCurrentActionName(agent: Types.Agent): string
	local plan = agent.decision.currentPlan
	if plan then
		local action = plan[agent.decision.currentActionIndex]
		if action then
			return action.id
		end
	end

	return "none"
end

local function shouldShowShotLine(config: Types.Config, agent: Types.Agent, now: number): boolean
	local combat = agent.combat
	return combat.lastShotOrigin ~= nil
		and combat.lastShotTarget ~= nil
		and combat.lastShotAt > 0
		and now - combat.lastShotAt <= config.Visualization.ShotFlashDuration
end

local function getFlatUnit(vector: Vector3): Vector3?
	local facing = vector
	local flatFacing = Vector3.new(facing.X, 0, facing.Z)
	if flatFacing.Magnitude < MIN_LINE_DISTANCE then
		return nil
	end

	return flatFacing.Unit
end

local function shouldSyncModelFromAgent(config: Types.Config): boolean
	return config.SimulationMode ~= "Spatial" or not config.NoobPath.Enabled
end

local function shouldUseNoobPathPathVisualization(config: Types.Config): boolean
	return config.SimulationMode == "Spatial" and config.NoobPath.Enabled
end

function VisualizationSystem:_getModelRecord(agent: Types.Agent): Types.AgentModelRecord?
	return self.agentModelStore:Get(agent.id)
end

function VisualizationSystem:_getRootPosition(agent: Types.Agent): Vector3
	local record = self:_getModelRecord(agent)
	if record then
		return record.rootPart.Position
	end

	return agent.transform.position + self.config.Visualization.VerticalOffset
end

function VisualizationSystem:_getFacing(agent: Types.Agent): Vector3?
	local record = self:_getModelRecord(agent)
	if record then
		local rootFacing = getFlatUnit(record.rootPart.CFrame.LookVector)
		if rootFacing then
			return rootFacing
		end
	end

	return getFlatUnit(agent.transform.facing)
end

function VisualizationSystem:_ensureLabel(agent: Types.Agent, parent: BasePart, offset: Vector3): TextLabel?
	if not self.config.Debug.ShowAgentLabels then
		return nil
	end

	local existingGui = self.labelGuis[agent.id]
	if existingGui and existingGui.Parent ~= parent then
		existingGui:Destroy()
		self.labelGuis[agent.id] = nil
		self.labels[agent.id] = nil
	end

	local label = self.labels[agent.id]
	if label then
		local gui = self.labelGuis[agent.id]
		if gui then
			gui.StudsOffsetWorldSpace = offset
		end
		return label
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "DebugLabel"
	gui.Size = UDim2.fromOffset(130, 36)
	gui.StudsOffsetWorldSpace = offset
	gui.AlwaysOnTop = true
	gui.Parent = parent

	label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Code
	label.TextSize = 15
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Parent = gui

	self.labelGuis[agent.id] = gui
	self.labels[agent.id] = label

	return label
end

function VisualizationSystem:Initialize(): ()
	local existing = Workspace:FindFirstChild(self.config.Visualization.FolderName)
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = self.config.Visualization.FolderName
	folder.Parent = Workspace
	self.folder = folder
end

function VisualizationSystem:_ensureAgentPart(agent: Types.Agent): BasePart
	local record = self:_getModelRecord(agent)
	if record then
		if self.parts[agent.id] then
			hideDebugPart(self.parts[agent.id])
		end

		self:_ensureLabel(agent, record.head, Vector3.new(0, 1.8, 0))
		return record.rootPart
	end

	if self.parts[agent.id] then
		return self.parts[agent.id]
	end

	local part = Instance.new("Part")
	part.Name = agent.id
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Size = self.config.Visualization.AgentSize
	part.Color = self.config.Teams[agent.teamId].Color
	part.CFrame = CFrame.new(agent.transform.position + self.config.Visualization.VerticalOffset)
	part.Parent = self.folder
	self.parts[agent.id] = part

	self:_ensureLabel(agent, part, Vector3.new(0, 5, 0))

	return part
end

function VisualizationSystem:_ensureDestinationMarker(agent: Types.Agent): BasePart
	if self.destinationMarkers[agent.id] then
		return self.destinationMarkers[agent.id]
	end

	local part = Instance.new("Part")
	configureDebugPart(
		part,
		agent.id .. "_PathDestination",
		self.config.Visualization.DestinationMarkerSize,
		self.config.Visualization.DestinationLineColor,
		Enum.PartType.Ball
	)
	part.Parent = self.folder
	self.destinationMarkers[agent.id] = part

	return part
end

function VisualizationSystem:_ensureDestinationLine(agent: Types.Agent): BasePart
	if self.destinationLines[agent.id] then
		return self.destinationLines[agent.id]
	end

	local thickness = self.config.Visualization.DestinationLineThickness
	local part = Instance.new("Part")
	configureDebugPart(
		part,
		agent.id .. "_PathLine",
		Vector3.new(thickness, thickness, 1),
		self.config.Visualization.DestinationLineColor,
		nil
	)
	part.Parent = self.folder
	self.destinationLines[agent.id] = part

	return part
end

function VisualizationSystem:_ensureShootingLine(agent: Types.Agent): BasePart
	if self.shootingLines[agent.id] then
		return self.shootingLines[agent.id]
	end

	local thickness = self.config.Visualization.ShootingLineThickness
	local part = Instance.new("Part")
	configureDebugPart(
		part,
		agent.id .. "_ShootingLine",
		Vector3.new(thickness, thickness, 1),
		self.config.Visualization.ShootingLineColor,
		nil
	)
	part.Parent = self.folder
	self.shootingLines[agent.id] = part

	return part
end

function VisualizationSystem:_ensureFacingArrowShaft(agent: Types.Agent): BasePart
	if self.facingArrowShafts[agent.id] then
		return self.facingArrowShafts[agent.id]
	end

	local thickness = self.config.Visualization.FacingArrowShaftThickness
	local part = Instance.new("Part")
	configureDebugPart(
		part,
		agent.id .. "_FacingArrowShaft",
		Vector3.new(thickness, thickness, 1),
		self.config.Visualization.FacingArrowColor,
		nil
	)
	part.Parent = self.folder
	self.facingArrowShafts[agent.id] = part

	return part
end

function VisualizationSystem:_updateDestinationDebug(agent: Types.Agent): ()
	if shouldUseNoobPathPathVisualization(self.config) then
		hideDebugPart(self.destinationMarkers[agent.id])
		hideDebugPart(self.destinationLines[agent.id])
		return
	end

	local destination = agent.movement.destination
	if not agent.stats.alive or not destination then
		hideDebugPart(self.destinationMarkers[agent.id])
		hideDebugPart(self.destinationLines[agent.id])
		return
	end

	local offset = self.config.Visualization.DestinationMarkerOffset
	local markerPosition = destination + offset
	local marker = self:_ensureDestinationMarker(agent)
	marker.CFrame = CFrame.new(markerPosition)
	marker.Transparency = 0.05

	local line = self:_ensureDestinationLine(agent)
	drawDebugLine(
		line,
		self:_getRootPosition(agent),
		markerPosition,
		self.config.Visualization.DestinationLineThickness,
		self.config.Visualization.DestinationLineColor,
		self.config.Visualization.DestinationLineTransparency
	)
end

function VisualizationSystem:_updateShootingDebug(agent: Types.Agent, now: number): ()
	if not agent.stats.alive or not shouldShowShotLine(self.config, agent, now) then
		hideDebugPart(self.shootingLines[agent.id])
		return
	end

	local origin = agent.combat.lastShotOrigin
	local target = agent.combat.lastShotTarget
	if not origin or not target then
		hideDebugPart(self.shootingLines[agent.id])
		return
	end

	local line = self:_ensureShootingLine(agent)
	drawDebugLine(
		line,
		origin,
		target,
		self.config.Visualization.ShootingLineThickness,
		self.config.Visualization.ShootingLineColor,
		self.config.Visualization.ShootingLineTransparency
	)
end

function VisualizationSystem:_updateFacingDebug(agent: Types.Agent): ()
	local facing = self:_getFacing(agent)
	if not agent.stats.alive or not facing then
		hideDebugPart(self.facingArrowShafts[agent.id])
		return
	end

	local config = self.config.Visualization
	local basePosition = self:_getRootPosition(agent) + config.FacingArrowOffset
	local shaftEndPosition = basePosition + facing * config.FacingArrowLength
	local shaft = self:_ensureFacingArrowShaft(agent)
	drawDebugLine(
		shaft,
		basePosition,
		shaftEndPosition,
		config.FacingArrowShaftThickness,
		config.FacingArrowColor,
		config.FacingArrowTransparency
	)
end

function VisualizationSystem:Step(dt: number, now: number): ()
	self.accumulator = self.accumulator + dt
	if self.accumulator < self.config.Cadence.VisualizationInterval then
		return
	end
	self.accumulator = 0

	for _, agent in ipairs(self.agentStore:GetAll()) do
		local record = self:_getModelRecord(agent)
		if record and shouldSyncModelFromAgent(self.config) then
			self.agentModelStore:SyncModelToAgent(agent)
		end

		local part = self:_ensureAgentPart(agent)
		if record then
			if not agent.stats.alive then
				self.agentModelStore:HideModel(agent.id)
			elseif not record.isStudioModel then
				local transparency = agent.stats.alive and self.config.AgentModel.DebugTransparency or 0.65
				record.rootPart.Transparency = transparency
				record.head.Transparency = transparency
			end
		else
			local targetCFrame = CFrame.new(agent.transform.position + self.config.Visualization.VerticalOffset)
			part.CFrame = part.CFrame:Lerp(targetCFrame, self.config.Visualization.LerpAlpha)
			part.Transparency = agent.stats.alive and 0 or 0.65
		end

		local label = self.labels[agent.id]
		if label then
			local goal = agent.decision.currentGoal or "none"
			local actionName = getCurrentActionName(agent)

			label.Text = ("%s\n%s/%s\nHP:%d"):format(agent.id, goal, actionName, agent.stats.health)
		end

		self:_updateDestinationDebug(agent)
		self:_updateShootingDebug(agent, now)
		self:_updateFacingDebug(agent)
	end
end

function VisualizationSystem.new(deps: Types.SystemDependencies): Types.VisualizationSystem
	local self = setmetatable({}, VisualizationSystem)

	self.config = deps.config
	self.agentStore = deps.agentStore
	self.parts = {}
	self.destinationMarkers = {}
	self.destinationLines = {}
	self.shootingLines = {}
	self.facingArrowShafts = {}
	self.labelGuis = {}
	self.labels = {}
	self.accumulator = 0
	self.folder = nil
	self.agentModelStore = deps.agentModelStore

	return self
end

return VisualizationSystem
