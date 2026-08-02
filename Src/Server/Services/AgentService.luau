--!strict

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CompyServerScripts = ServerScriptService.CompyAgent
local CompySharedScripts = ReplicatedStorage.CompyAgent

local Agent = require(CompyServerScripts.Agents.Agent)
local EnvironmentService = require(CompyServerScripts.Services.EnvironmentService)
local Team = require(CompySharedScripts.Team)
local SPHAgentFactory = require(CompyServerScripts.Integrations.Spearhead.SPHAgentFactory)

local Configs = require(CompySharedScripts.Config)

local AgentService = {}
AgentService.__index = AgentService

local DEFAULT_POSITION_UPDATE_INTERVAL = 0.1

export type AgentId = number

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
	updateHeartbeat: RBXScriptConnection?,
	nextAgentId: number,
	idByAgent: { [Agent.Agent]: AgentId },
	agents: { [AgentId]: Agent.Agent },
	agentTeams: { [AgentId]: Team.Id },
	agentPositions: { [AgentId]: Vector3 },
	agentLifeCycles: { [AgentId]: LifecycleConnections },
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
	if self.agents[id] ~= expectedAgent then
		return false
	end

	self.agents[id] = nil
	self.idByAgent[expectedAgent] = nil
	self.agentTeams[id] = nil
	self.agentPositions[id] = nil

	local lifecycle = self.agentLifeCycles[id]
	self.agentLifeCycles[id] = nil
	if lifecycle then
		disconnectLifecycle(lifecycle)
	end

	return true
end

local function registerAgent(self: AgentService, agent: Agent.Agent, teamId: Team.Id): AgentId?
	Team.AssertKnown(self.teams, teamId)
	assert(agent.teamId == teamId, "AgentService registration teamId must match Agent.teamId")

	local id = agent.id

	local humanoid, model = getLiveAgentModel(agent)
	if not humanoid or not model then
		return nil
	end

	self.idByAgent[agent] = id
	self.agents[id] = agent
	self.agentTeams[id] = teamId
	self.agentPositions[id] = model:GetPivot().Position

	local lifecycle: LifecycleConnections = {
		diedConnection = nil,
		humanoidDestroyingConnection = nil,
		modelDestroyingConnection = nil,
	}
	self.agentLifeCycles[id] = lifecycle

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

function AgentService.CreateAgent(self: AgentService, spawnCFrame: CFrame, config: SPHAgentFactory.AgentConfig): Agent.Agent
	local agentId = self.nextAgentId
	self.nextAgentId += 1

	local agentName = `Agent{agentId}`

	local controller = SPHAgentFactory.Create(agentName, spawnCFrame, config)
	local agent = Agent.new(agentId, config.teamId, controller, Configs.Agent, Configs.Cadence, self)

	registerAgent(self, agent, config.teamId)
	return agent
end

function AgentService.Start(self: AgentService): ()
	if self.running then
		return
	end

	self.running = true
	self.updateElapsed = 0
	self.updateHeartbeat = RunService.Heartbeat:Connect(function(deltaTime: number): ()
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
	for id, agent in pairs(self.agents) do
		local _, model = getLiveAgentModel(agent)
		if model and agent.alive then
			self.agentPositions[id] = model:GetPivot().Position
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

	if self.updateHeartbeat then
		self.updateHeartbeat:Disconnect()
		self.updateHeartbeat = nil
	end

	for _, lifecycle in pairs(self.agentLifeCycles) do
		disconnectLifecycle(lifecycle)
	end

	table.clear(self.agentLifeCycles)
	table.clear(self.agentPositions)
	table.clear(self.agentTeams)
	table.clear(self.agents)
	table.clear(self.idByAgent)
end

function AgentService.GetId(self: AgentService, agent: Agent.Agent): AgentId?
	return self.idByAgent[agent]
end

function AgentService.GetAgent(self: AgentService, id: AgentId): Agent.Agent?
	return self.agents[id]
end

function AgentService.GetAgentByName(self: AgentService, name: string): Agent.Agent?
	for _, agent in self.agents do
		local agentName = agent.controller:GetModel().Name

		if agentName ~= nil and agentName == name then
			return agent
		end
	end

	return nil
end

function AgentService.GetTeamId(self: AgentService, id: AgentId): Team.Id?
	return self.agentTeams[id]
end

function AgentService.GetLastRecordedPosition(self: AgentService, id: AgentId): Vector3?
	return self.agentPositions[id]
end

local function getNearbyAgents(self: AgentService, origin: Vector3, radius: number, include: (id: AgentId, teamId: Team.Id, agent: Agent.Agent) -> boolean): { NearbyAgent }
	assert(isFiniteVector3(origin), "AgentService query origin must be finite")
	assert(isFiniteNumber(radius) and radius >= 0, "AgentService query radius must be a finite nonnegative number")
	local radiusSquared = radius * radius
	local nearbyAgents: { NearbyAgent } = {}
	local staleAgents: { { id: AgentId, agent: Agent.Agent } } = {}
	for id, position in pairs(self.agentPositions) do
		local agent = self.agents[id]
		local teamId = self.agentTeams[id]
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

function AgentService.GetNearbyAgents(self: AgentService, origin: Vector3, radius: number, excludeAgent: Agent.Agent?): { NearbyAgent }
	return getNearbyAgents(self, origin, radius, function(_id: AgentId, _teamId: Team.Id, agent: Agent.Agent): boolean
		return agent ~= excludeAgent
	end)
end

function AgentService.GetNearbyEnemyAgents(self: AgentService, queryingTeamId: Team.Id, origin: Vector3, radius: number, excludeAgentId: AgentId?): { NearbyAgent }
	Team.AssertKnown(self.teams, queryingTeamId)
	if excludeAgentId ~= nil then
		assert(isFiniteNumber(excludeAgentId) and excludeAgentId > 0 and excludeAgentId % 1 == 0, "AgentService.GetNearbyEnemyAgents excludeAgentId must be a positive integer")
	end

	return getNearbyAgents(self, origin, radius, function(id: AgentId, teamId: Team.Id, _agent: Agent.Agent): boolean
		return id ~= excludeAgentId and teamId ~= queryingTeamId
	end)
end

function AgentService.GetNearbyAgentHeads(self: AgentService, queryingTeamId: Team.Id, origin: Vector3, radius: number, excludeAgentId: AgentId?): { BasePart }
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

local agentServiceConfig = Configs.Simulation.AgentService
local positionUpdateInterval = agentServiceConfig.PositionUpdateInterval or DEFAULT_POSITION_UPDATE_INTERVAL
assert(isFiniteNumber(positionUpdateInterval) and positionUpdateInterval > 0, "AgentService PositionUpdateInterval must be a finite positive number")

local singleton: AgentService = setmetatable({
	teams = Configs.Teams,
	positionUpdateInterval = positionUpdateInterval,
	updateElapsed = 0,
	running = false,
	updateHeartbeat = nil,
	nextAgentId = 1,
	idByAgent = {},
	agents = {},
	agentTeams = {},
	agentPositions = {},
	agentLifeCycles = {},
}, AgentService)

return singleton
