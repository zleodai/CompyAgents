local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CompyServerScripts = ServerScriptService.CompyAgent
local CompySharedScripts = ReplicatedStorage.CompyAgent

local Agent = require(CompyServerScripts.Agents.Agent)
local SoundService = require(CompyServerScripts.Services.SoundService)
local DebugService = require(CompyServerScripts.Services.DebugService)
local AgentService = require(CompyServerScripts.Services.AgentService)
local EnvironmentService = require(CompyServerScripts.Services.EnvironmentService)
local _DefaultConfig = require(CompySharedScripts.Config)
local Team = require(CompySharedScripts.Team)

local Simulation = {}
Simulation.__index = Simulation

type SimulationData = {
	config: typeof(_DefaultConfig),
	started: boolean,
	starting: boolean,
	agents: { Agent.Agent },
	spawnedAgentCountByTeam: { [Team.Id]: number },
}

export type Simulation = typeof(setmetatable({} :: SimulationData, Simulation))

local function getSpawnCFrame(teamId: Team.Id): CFrame
	local spawnPoints: { EnvironmentService.SpawnPointRecord } = EnvironmentService:QueryAllSpawnPoints({ teamId = teamId })
	if #spawnPoints > 0 then
		local spawnPoint = spawnPoints[math.random(1, #spawnPoints)]
		local position = spawnPoint.position
		if spawnPoint.spawnRadius > 0 then
			local angle = math.random() * math.pi * 2
			local distance = math.sqrt(math.random()) * spawnPoint.spawnRadius
			position += Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		end
		return CFrame.lookAt(position, position + spawnPoint.facing)
	end

	error(`No Studio spawn is available for team {teamId}`)
end

local function destroyAgent(agent: Agent.Agent): ()
	local model = agent.controller:GetModel()
	agent:End()
	if model.Parent then
		model:Destroy()
	end
end

function Simulation.SpawnAgents(self: Simulation): ()
	local firstNewAgentIndex = #self.agents + 1
	local teamIds: { Team.Id } = {}
	local previousSpawnedAgentCountByTeam: { [Team.Id]: number? } = {}
	for teamId in pairs(self.config.Teams) do
		table.insert(teamIds, teamId)
		previousSpawnedAgentCountByTeam[teamId] = self.spawnedAgentCountByTeam[teamId]
	end
	table.sort(teamIds)

	for _, teamId in ipairs(teamIds) do
		Team.AssertKnown(self.config.Teams, teamId)

		for _index = 1, self.config.Simulation.DemoAgentsPerTeam do
			local agentTeamId = teamId
			local spawnIndex = (self.spawnedAgentCountByTeam[agentTeamId] or 0) + 1
			local spawnCFrame = getSpawnCFrame(agentTeamId)
			local agent = AgentService:CreateAgent(spawnCFrame, { teamId = teamId })
			self.spawnedAgentCountByTeam[agentTeamId] = spawnIndex
			table.insert(self.agents, agent)
		end
	end

	if not self.starting then
		for index = firstNewAgentIndex, #self.agents do
			self.agents[index]:Start()
		end
	end
end

function Simulation.Start(self: Simulation): ()
	if self.started then
		return
	end
	self.started = true
	self.starting = true

	task.defer(function()
		SoundService:Start()
		DebugService:Start()
		EnvironmentService:Start()

		task.wait(0.5)

		self:SpawnAgents()

		task.wait(0.5)

		AgentService:Start()
		for _, agent in ipairs(self.agents) do
			agent:Start()
		end
	end)
end

function Simulation.Stop(self: Simulation): ()
	if not self.started then
		return
	end
	self.started = false
	self.starting = false

	SoundService:End()
	DebugService:End()
	AgentService:End()
	EnvironmentService:End()
	for _, agent in ipairs(self.agents) do
		destroyAgent(agent)
	end
	table.clear(self.agents)
end

function Simulation.new(config: typeof(_DefaultConfig)): Simulation
	return setmetatable({
		config = config,
		started = false,
		starting = false,
		agents = {},
		spawnedAgentCountByTeam = {},
	}, Simulation)
end

return Simulation
