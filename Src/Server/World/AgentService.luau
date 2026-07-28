--!strict

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CompyServerScripts = ServerScriptService.CompyAgent
local CompySharedScripts = ReplicatedStorage.CompyAgent

local Agent = require(CompyServerScripts.Agents.Agent)
local Team = require(CompySharedScripts.Team)

local AgentService = {}
AgentService.__index = AgentService

local DEFAULT_POSITION_UPDATE_INTERVAL = 0.1

export type AgentId = number

export type Config = {
	PositionUpdateInterval: number?,
}

export type NearbyAgent = {
	id: AgentId,
	teamId: Team.Id,
	agent: Agent.Agent,
	position: Vector3,
	distanceSquared: number,
}

type LifecycleConnections = {
	diedConnection: RBXScriptConnection?,
	humanoidDestroyingConnection: RBXScriptConnection?,
	modelDestroyingConnection: RBXScriptConnection?,
}

type AgentServiceData = {
	teams: Team.Registry,
	positionUpdateInterval: number,
	updateElapsed: number,
	running: boolean,
	heartbeatConnection: RBXScriptConnection?,
	idByAgent: { [Agent.Agent]: AgentId },
	agentById: { [AgentId]: Agent.Agent },
	teamIdById: { [AgentId]: Team.Id },
	lastRecordedPositionById: { [AgentId]: Vector3 },
	lifecycleById: { [AgentId]: LifecycleConnections },
}

export type AgentService = typeof(setmetatable({} :: AgentServiceData, AgentService))

local function isFiniteNumber(value: number): boolean
	return value == value and math.abs(value) < math.huge
end

local function isFiniteVector3(value: Vector3): boolean
	return isFiniteNumber(value.X) and isFiniteNumber(value.Y) and isFiniteNumber(value.Z)
end

local function disconnectLifecycle(lifecycle: LifecycleConnections): ()
	if lifecycle.diedConnection then
		lifecycle.diedConnection:Disconnect()
		lifecycle.diedConnection = nil
	end
	if lifecycle.humanoidDestroyingConnection then
		lifecycle.humanoidDestroyingConnection:Disconnect()
		lifecycle.humanoidDestroyingConnection = nil
	end
	if lifecycle.modelDestroyingConnection then
		lifecycle.modelDestroyingConnection:Disconnect()
		lifecycle.modelDestroyingConnection = nil
	end
end

local function getLiveAgentModel(agent: Agent.Agent): (Humanoid?, Model?)
	local humanoid = agent.controller:GetHumanoid()
	local model = agent.controller:GetModel()
	if humanoid.Health <= 0 or humanoid.Parent == nil or model.Parent == nil or not humanoid:IsDescendantOf(model) then
		return nil, nil
	end
	return humanoid, model
end

local function removeById(self: AgentService, id: AgentId, expectedAgent: Agent.Agent): boolean
	if self.agentById[id] ~= expectedAgent then
		return false
	end

	self.agentById[id] = nil
	self.idByAgent[expectedAgent] = nil
	self.teamIdById[id] = nil
	self.lastRecordedPositionById[id] = nil

	local lifecycle = self.lifecycleById[id]
	self.lifecycleById[id] = nil
	if lifecycle then
		disconnectLifecycle(lifecycle)
	end

	return true
end

function AgentService.Start(self: AgentService): ()
	if self.running then
		return
	end

	self.running = true
	self.updateElapsed = 0
	self.heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime: number): ()
		self:Update(deltaTime)
	end)
end

function AgentService.Update(self: AgentService, deltaTime: number): ()
	assert(isFiniteNumber(deltaTime) and deltaTime >= 0, "AgentService.Update deltaTime must be a finite nonnegative number")
	if not self.running then
		return
	end

	self.updateElapsed += deltaTime
	if self.updateElapsed < self.positionUpdateInterval then
		return
	end
	self.updateElapsed = self.updateElapsed % self.positionUpdateInterval

	local staleAgents: { { id: AgentId, agent: Agent.Agent } } = {}
	for id, agent in pairs(self.agentById) do
		local _, model = getLiveAgentModel(agent)
		if model then
			self.lastRecordedPositionById[id] = model:GetPivot().Position
		else
			table.insert(staleAgents, {
				id = id,
				agent = agent,
			})
		end
	end

	for _, staleAgent in ipairs(staleAgents) do
		removeById(self, staleAgent.id, staleAgent.agent)
	end
end

function AgentService.End(self: AgentService): ()
	self.running = false
	self.updateElapsed = 0

	if self.heartbeatConnection then
		self.heartbeatConnection:Disconnect()
		self.heartbeatConnection = nil
	end

	for _, lifecycle in pairs(self.lifecycleById) do
		disconnectLifecycle(lifecycle)
	end

	table.clear(self.lifecycleById)
	table.clear(self.lastRecordedPositionById)
	table.clear(self.teamIdById)
	table.clear(self.agentById)
	table.clear(self.idByAgent)
end

function AgentService.Register(self: AgentService, agent: Agent.Agent, teamId: Team.Id): AgentId?
	Team.AssertKnown(self.teams, teamId)
	assert(agent.teamId == teamId, "AgentService registration teamId must match Agent.teamId")

	local existingId = self.idByAgent[agent]
	if existingId then
		assert(existingId == agent.id, "A registered Agent's id must not change")
		assert(self.teamIdById[existingId] == teamId, "A registered Agent's teamId must not change")
		local _, existingModel = getLiveAgentModel(agent)
		if existingModel then
			return existingId
		end
		removeById(self, existingId, agent)
		return nil
	end

	local id = agent.id
	assert(isFiniteNumber(id) and id > 0 and id % 1 == 0, "Agent.id must be a positive integer")
	local conflictingAgent = self.agentById[id]
	assert(conflictingAgent == nil, `Agent id {id} is already registered to a different Agent`)

	local humanoid, model = getLiveAgentModel(agent)
	if not humanoid or not model then
		return nil
	end

	self.idByAgent[agent] = id
	self.agentById[id] = agent
	self.teamIdById[id] = teamId
	self.lastRecordedPositionById[id] = model:GetPivot().Position

	local lifecycle: LifecycleConnections = {
		diedConnection = nil,
		humanoidDestroyingConnection = nil,
		modelDestroyingConnection = nil,
	}
	self.lifecycleById[id] = lifecycle

	lifecycle.diedConnection = humanoid.Died:Connect(function(): ()
		removeById(self, id, agent)
	end)
	lifecycle.humanoidDestroyingConnection = humanoid.Destroying:Connect(function(): ()
		removeById(self, id, agent)
	end)
	lifecycle.modelDestroyingConnection = model.Destroying:Connect(function(): ()
		removeById(self, id, agent)
	end)

	return id
end

function AgentService.Unregister(self: AgentService, agent: Agent.Agent): boolean
	local id = self.idByAgent[agent]
	if not id then
		return false
	end
	return removeById(self, id, agent)
end

function AgentService.GetId(self: AgentService, agent: Agent.Agent): AgentId?
	return self.idByAgent[agent]
end

function AgentService.GetAgent(self: AgentService, id: AgentId): Agent.Agent?
	return self.agentById[id]
end

function AgentService.GetTeamId(self: AgentService, id: AgentId): Team.Id?
	return self.teamIdById[id]
end

function AgentService.GetLastRecordedPosition(self: AgentService, id: AgentId): Vector3?
	return self.lastRecordedPositionById[id]
end

local function getNearbyAgents(
	self: AgentService,
	origin: Vector3,
	radius: number,
	include: (id: AgentId, teamId: Team.Id, agent: Agent.Agent) -> boolean
): { NearbyAgent }
	assert(isFiniteVector3(origin), "AgentService query origin must be finite")
	assert(isFiniteNumber(radius) and radius >= 0, "AgentService query radius must be a finite nonnegative number")
	local radiusSquared = radius * radius
	local nearbyAgents: { NearbyAgent } = {}
	local staleAgents: { { id: AgentId, agent: Agent.Agent } } = {}
	for id, position in pairs(self.lastRecordedPositionById) do
		local agent = self.agentById[id]
		local teamId = self.teamIdById[id]
		if agent and teamId then
			local _, model = getLiveAgentModel(agent)
			if not model then
				table.insert(staleAgents, { id = id, agent = agent })
			elseif include(id, teamId, agent) then
				local offset = position - origin
				local distanceSquared = offset:Dot(offset)
				if distanceSquared <= radiusSquared then
					table.insert(nearbyAgents, {
						id = id,
						teamId = teamId,
						agent = agent,
						position = position,
						distanceSquared = distanceSquared,
					})
				end
			end
		end
	end

	for _, staleAgent in ipairs(staleAgents) do
		removeById(self, staleAgent.id, staleAgent.agent)
	end

	table.sort(nearbyAgents, function(a: NearbyAgent, b: NearbyAgent): boolean
		if a.distanceSquared == b.distanceSquared then
			return a.id < b.id
		end
		return a.distanceSquared < b.distanceSquared
	end)

	return nearbyAgents
end

function AgentService.GetNearbyAgents(
	self: AgentService,
	origin: Vector3,
	radius: number,
	excludeAgent: Agent.Agent?
): { NearbyAgent }
	return getNearbyAgents(self, origin, radius, function(_id: AgentId, _teamId: Team.Id, agent: Agent.Agent): boolean
		return agent ~= excludeAgent
	end)
end

function AgentService.GetNearbyEnemyAgents(
	self: AgentService,
	queryingTeamId: Team.Id,
	origin: Vector3,
	radius: number,
	excludeAgentId: AgentId?
): { NearbyAgent }
	Team.AssertKnown(self.teams, queryingTeamId)
	if excludeAgentId ~= nil then
		assert(
			isFiniteNumber(excludeAgentId) and excludeAgentId > 0 and excludeAgentId % 1 == 0,
			"AgentService.GetNearbyEnemyAgents excludeAgentId must be a positive integer"
		)
	end

	return getNearbyAgents(self, origin, radius, function(id: AgentId, teamId: Team.Id, _agent: Agent.Agent): boolean
		return id ~= excludeAgentId and teamId ~= queryingTeamId
	end)
end

function AgentService.GetNearbyAgentHeads(
	self: AgentService,
	queryingTeamId: Team.Id,
	origin: Vector3,
	radius: number,
	excludeAgentId: AgentId?
): { BasePart }
	local nearbyEnemies = self:GetNearbyEnemyAgents(queryingTeamId, origin, radius, excludeAgentId)
	local heads: { BasePart } = {}

	for _, nearbyEnemy in ipairs(nearbyEnemies) do
		local controller = nearbyEnemy.agent.controller
		local model = controller:GetModel()
		local head = controller:GetHeadPart()
		if head.Parent ~= nil and head:IsDescendantOf(model) then
			table.insert(heads, head)
		end
	end

	return heads
end

function AgentService.new(config: Config?, teams: Team.Registry): AgentService
	assert(teams ~= nil, "AgentService requires the authoritative team registry")
	local positionUpdateInterval = if config and config.PositionUpdateInterval ~= nil
		then config.PositionUpdateInterval
		else DEFAULT_POSITION_UPDATE_INTERVAL
	assert(
		isFiniteNumber(positionUpdateInterval) and positionUpdateInterval > 0,
		"AgentService PositionUpdateInterval must be a finite positive number"
	)

	return setmetatable({
		teams = teams,
		positionUpdateInterval = positionUpdateInterval,
		updateElapsed = 0,
		running = false,
		heartbeatConnection = nil,
		idByAgent = {},
		agentById = {},
		teamIdById = {},
		lastRecordedPositionById = {},
		lifecycleById = {},
	}, AgentService)
end

return AgentService
