--[=[
	NoobPathMovement

	Spatial movement driver that lets NoobPath own humanoid path computation and
	MoveTo progression. AgentMovement.destination remains the request surface.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local NoobPath = require(ReplicatedStorage.Packages.NoobPath)

local NoobPathMovement = {}
NoobPathMovement.__index = NoobPathMovement

type Disconnectable = {
	Disconnect: (Disconnectable) -> (),
}

type PathAgentRecord = {
	pathAgent: any,
	lastDestination: Vector3?,
	stopped: boolean,
	connections: { Disconnectable },
}

local function positionsClose(a: Vector3, b: Vector3, tolerance: number): boolean
	return (a - b).Magnitude <= tolerance
end

local function resetPathRequest(agent: Types.Agent): ()
	agent.movement.path = nil
	agent.movement.pathIndex = 1
	agent.movement.needsPath = false
	agent.movement.pathQueued = false
end

local function getFlatUnit(vector: Vector3): Vector3?
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude <= 0.001 then
		return nil
	end

	return flat.Unit
end

function NoobPathMovement:_hidePathVisualization(record: PathAgentRecord): ()
	if record.pathAgent and record.pathAgent.Hide then
		local ok, err = pcall(function(): ()
			record.pathAgent:Hide()
		end)

		if not ok then
			warn(("[CompyAgent:NoobPathMovement] Hide failed: %s"):format(tostring(err)))
		end
	end
end

function NoobPathMovement:_syncAgentFromModel(agent: Types.Agent): ()
	local modelRecord = self.agentModelStore:Get(agent.id)
	if not modelRecord then
		return
	end

	local rootPart = modelRecord.rootPart
	local previousPosition = agent.transform.position
	local groundedPosition = rootPart.Position - Vector3.new(0, modelRecord.groundToRootOffset, 0)
	agent.transform.position = groundedPosition

	local facing = getFlatUnit(rootPart.CFrame.LookVector)
	local movementFacing = getFlatUnit(groundedPosition - previousPosition)
	if movementFacing then
		agent.transform.facing = movementFacing
	elseif facing then
		agent.transform.facing = facing
	end
end

function NoobPathMovement:_handleReached(agent: Types.Agent, record: PathAgentRecord): ()
	local movement = agent.movement
	movement.arrived = true
	movement.mode = "Idle"
	movement.destination = nil
	resetPathRequest(agent)
	record.lastDestination = nil
	record.stopped = true
	self:_hidePathVisualization(record)
	self:_syncAgentFromModel(agent)
end

function NoobPathMovement:_handleTrapped(agent: Types.Agent, record: PathAgentRecord): ()
	agent.movement.needsPath = true
	agent.movement.pathQueued = false
	record.lastDestination = nil
	record.stopped = false
end

function NoobPathMovement:_handleError(agent: Types.Agent, record: PathAgentRecord, errorType: any): ()
	local movement = agent.movement
	movement.mode = "Idle"
	movement.arrived = false
	movement.destination = nil
	resetPathRequest(agent)

	agent.decision.needsPlan = true
	agent.decision.lastPlanReason = "noobpath_error:" .. tostring(errorType)

	record.lastDestination = nil
	record.stopped = true
	self:_hidePathVisualization(record)
end

function NoobPathMovement:_ensurePathAgent(agent: Types.Agent): PathAgentRecord?
	local existingRecord = self.pathAgents[agent.id]
	if existingRecord then
		return existingRecord
	end

	local model = self.agentModelStore:GetModel(agent.id)
	if not model then
		local created = self.agentModelStore:CreateForAgent(agent)
		if not created then
			return nil
		end

		model = created.model
	end

	local humanoid = self.agentModelStore:GetHumanoid(agent.id)
	if humanoid then
		humanoid.WalkSpeed = self.config.AgentModel.WalkSpeed
	end

	local pathAgent = NoobPath.Humanoid(model, self.config.NoobPath.AgentParams, self.config.NoobPath.Precise)
	pathAgent.Timeout = self.config.NoobPath.Timeout
	pathAgent.Speed = self.config.Movement.Speed
	pathAgent.Visualize = self.config.NoobPath.Visualize

	local record: PathAgentRecord = {
		pathAgent = pathAgent,
		lastDestination = nil,
		stopped = true,
		connections = {},
	}

	table.insert(record.connections, pathAgent.Reached:Connect(function(_waypoint: any, _isPartial: any): ()
		self:_handleReached(agent, record)
	end))

	table.insert(record.connections, pathAgent.WaypointReached:Connect(function(_waypoint: any, _nextWaypoint: any): ()
		agent.movement.mode = "Moving"
		self:_syncAgentFromModel(agent)
	end))

	table.insert(record.connections, pathAgent.Trapped:Connect(function(_trapType: any): ()
		self:_handleTrapped(agent, record)
	end))

	table.insert(record.connections, pathAgent.Error:Connect(function(errorType: any): ()
		self:_handleError(agent, record, errorType)
	end))

	table.insert(record.connections, pathAgent.Stopped:Connect(function(): ()
		record.stopped = true
		if agent.movement.destination == nil then
			agent.movement.mode = "Idle"
		end
	end))

	self.pathAgents[agent.id] = record
	return record
end

function NoobPathMovement:_stopAgent(agent: Types.Agent): ()
	local record = self.pathAgents[agent.id]
	if not record or record.stopped then
		return
	end

	local ok, err = pcall(function(): ()
		record.pathAgent:Stop()
	end)

	if not ok then
		warn(("[CompyAgent:NoobPathMovement] Stop failed for %s: %s"):format(agent.id, tostring(err)))
	end

	record.lastDestination = nil
	record.stopped = true
	self:_hidePathVisualization(record)
end

function NoobPathMovement:SetPath(agent: Types.Agent, _pathResult: Types.PathResult): ()
	resetPathRequest(agent)
end

function NoobPathMovement:Step(agent: Types.Agent, _dt: number): Types.MovementStatus
	if not agent.stats.alive then
		self:_stopAgent(agent)
		agent.movement.mode = "Idle"
		return "Idle"
	end

	local record = self:_ensurePathAgent(agent)
	if not record then
		return "Idle"
	end

	record.pathAgent.Visualize = self.config.NoobPath.Visualize
	if not self.config.NoobPath.Visualize then
		self:_hidePathVisualization(record)
	end

	self:_syncAgentFromModel(agent)

	local destination = agent.movement.destination
	if not destination then
		self:_stopAgent(agent)
		agent.movement.mode = "Idle"
		return "Idle"
	end

	local shouldRun = record.lastDestination == nil
		or not positionsClose(record.lastDestination, destination, self.config.Movement.WaypointTolerance)

	if shouldRun then
		agent.movement.arrived = false
		agent.movement.mode = "Moving"
		resetPathRequest(agent)
		record.lastDestination = destination
		record.stopped = false

		local ok, err = pcall(function(): ()
			record.pathAgent:Run(destination)
		end)

		if not ok then
			self:_handleError(agent, record, err)
			warn(("[CompyAgent:NoobPathMovement] Run failed for %s: %s"):format(agent.id, tostring(err)))
			return "Idle"
		end
	end

	self:_syncAgentFromModel(agent)
	return "Moving"
end

function NoobPathMovement.new(config: Types.Config, agentModelStore: Types.AgentModelStore): Types.NoobPathMovementDriver
	local self = setmetatable({}, NoobPathMovement)

	self.config = config
	self.agentModelStore = agentModelStore
	self.pathAgents = {}

	return self
end

return NoobPathMovement
