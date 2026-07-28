local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CompyServerScripts = ServerScriptService.CompyAgent
local CompySharedScripts = ReplicatedStorage.CompyAgent

local SPHAgentFactory = require(CompyServerScripts.Integrations.Spearhead.SPHAgentFactory)
local SPHController = require(CompyServerScripts.Integrations.Spearhead.SPHController)

local Agent = require(CompyServerScripts.Agents.Agent)
local AgentService = require(CompyServerScripts.World.AgentService)
local EnvironmentService = require(CompyServerScripts.World.EnvironmentService)
local _DefaultConfig = require(CompySharedScripts.Config)
local Team = require(CompySharedScripts.Team)

local Simulation = {}
Simulation.__index = Simulation

type SimulationData = {
	config: typeof(_DefaultConfig),
	started: boolean,
	starting: boolean,
	agents: { Agent.Agent },
	agentService: AgentService.AgentService,
	environment: EnvironmentService.EnvironmentService,
	nextAgentId: number,
	spawnedAgentCountByTeam: { [Team.Id]: number },
}

export type Simulation = typeof(setmetatable({} :: SimulationData, Simulation))

local function getSpawnCFrame(self: Simulation, teamId: Team.Id, index: number): CFrame
	assert(index >= 1 and index % 1 == 0, "index must be a positive integer")

	local spawnPoints: { EnvironmentService.SpawnPointRecord } = self.environment:QueryAllSpawnPoints({
		teamId = teamId,
	})
	if #spawnPoints > 0 then
		local spawnPoint = spawnPoints[((index - 1) % #spawnPoints) + 1]
		local position = spawnPoint.position
		if spawnPoint.spawnRadius > 0 then
			local angle = math.random() * math.pi * 2
			local distance = math.sqrt(math.random()) * spawnPoint.spawnRadius
			position += Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		end
		return CFrame.lookAt(position, position + spawnPoint.facing)
	end

	if not self.config.Simulation.UseConfigSpawnsFallback then
		error(`No Studio spawn is available for team {teamId}`)
	end

	local teamConfig = self.config.Teams[teamId]
	assert(teamConfig, `Missing team config for {teamId}`)
	local position = teamConfig.SpawnOrigin + Vector3.new(0, 0, (index - 1) * teamConfig.SpawnSpacing)
	return CFrame.lookAt(position, position + teamConfig.Forward)
end

local function destroyAgent(agent: Agent.Agent): ()
	local model = agent.controller:GetModel()
	agent:End()
	if model.Parent then
		model:Destroy()
	end
end

local function destroyController(controller: SPHController.SPHController): ()
	local model = controller:GetModel()
	controller:Destroy()
	if model.Parent then
		model:Destroy()
	end
end

function Simulation.SpawnAgents(self: Simulation): ()
	assert(self.started, "Simulation must be started before spawning Agents")
	local firstNewAgentIndex = #self.agents + 1
	local teamIds: { Team.Id } = {}
	local previousSpawnedAgentCountByTeam: { [Team.Id]: number? } = {}
	for teamId in pairs(self.config.Teams) do
		table.insert(teamIds, teamId)
		previousSpawnedAgentCountByTeam[teamId] = self.spawnedAgentCountByTeam[teamId]
	end
	table.sort(teamIds)

	local spawnSucceeded, spawnError = xpcall(function(): ()
		for _, teamId in ipairs(teamIds) do
			Team.AssertKnown(self.config.Teams, teamId)
			local factory = SPHAgentFactory.new({
				teamId = teamId,
				maxHealth = self.config.Agent.MaxHealth,
				controllerConfig = {
					modelNames = self.config.Teams[teamId].Models,
					weaponName = "AKM",
					moveTimeout = 30,
					aimSpeed = 0.4,
				},
			})

			for _index = 1, self.config.Simulation.DemoAgentsPerTeam do
				local agentTeamId = teamId
				local spawnIndex = (self.spawnedAgentCountByTeam[agentTeamId] or 0) + 1
				local agentName = ("%s_%02d"):format(agentTeamId, spawnIndex)
				local spawnCFrame = getSpawnCFrame(self, agentTeamId, spawnIndex)

				local controller = factory:Create(agentName, spawnCFrame)
				local agentId = self.nextAgentId
				self.nextAgentId += 1
				local constructed, agentOrError = pcall(function(): Agent.Agent
					return Agent.new(agentId, agentTeamId, controller, self.config.Agent, self.config.Cadence, {
						agentService = self.agentService,
						environmentService = self.environment,
					})
				end)
				if not constructed then
					destroyController(controller)
					error(agentOrError, 0)
				end
				local agent = agentOrError :: Agent.Agent

				local registered, registeredId = pcall(function(): AgentService.AgentId?
					return self.agentService:Register(agent, agentTeamId)
				end)
				if not registered or not registeredId then
					destroyAgent(agent)
					if not registered then
						error(registeredId, 0)
					end
					error(`Agent {agentId} died or was destroyed before registration`)
				end
				self.spawnedAgentCountByTeam[agentTeamId] = spawnIndex
				table.insert(self.agents, agent)
			end
		end

		if not self.starting then
			for index = firstNewAgentIndex, #self.agents do
				self.agents[index]:Start()
			end
		end
	end, debug.traceback)

	if not spawnSucceeded then
		for index = #self.agents, firstNewAgentIndex, -1 do
			local agent = self.agents[index]
			self.agentService:Unregister(agent)
			table.remove(self.agents, index)
			destroyAgent(agent)
		end
		for _, teamId in ipairs(teamIds) do
			self.spawnedAgentCountByTeam[teamId] = previousSpawnedAgentCountByTeam[teamId] or 0
		end
		error(spawnError, 0)
	end
end

function Simulation.RemoveAgent(self: Simulation, agent: Agent.Agent): boolean
	local agentIndex = table.find(self.agents, agent)
	if not agentIndex then
		return false
	end

	self.agentService:Unregister(agent)
	table.remove(self.agents, agentIndex)
	destroyAgent(agent)
	return true
end

function Simulation.Start(self: Simulation): ()
	if self.started then
		return
	end
	self.started = true
	self.starting = true

	local startedSuccessfully, startError = xpcall(function(): ()
		self.environment:Start()
		self.agentService:Start()
		self:SpawnAgents()
		for _, agent in ipairs(self.agents) do
			agent:Start()
		end
	end, debug.traceback)

	if not startedSuccessfully then
		self.agentService:End()
		self.environment:End()
		for _, agent in ipairs(self.agents) do
			destroyAgent(agent)
		end
		table.clear(self.agents)
		self.started = false
		self.starting = false
		error(startError, 0)
	end
	self.starting = false
end

function Simulation.Stop(self: Simulation): ()
	if not self.started then
		return
	end
	self.started = false
	self.starting = false

	self.agentService:End()
	self.environment:End()
	for _, agent in ipairs(self.agents) do
		destroyAgent(agent)
	end
	table.clear(self.agents)
end

function Simulation.new(config: typeof(_DefaultConfig)): Simulation
	local agentService = AgentService.new(config.Simulation.AgentService, config.Teams)
	local environment = EnvironmentService.new(config)

	return setmetatable({
		config = config,
		started = false,
		starting = false,
		agents = {},
		agentService = agentService,
		environment = environment,
		nextAgentId = 1,
		spawnedAgentCountByTeam = {},
	}, Simulation)
end

return Simulation
