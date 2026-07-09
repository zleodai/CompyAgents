local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local AgentModelStore = require(CompyServerScripts.Agents.AgentModelStore)
local AgentRuntime = require(CompyServerScripts.Agents.AgentRuntime)
local AgentState = require(CompyServerScripts.Agents.AgentState)
local BlackboardStore = require(CompyServerScripts.Blackboard.BlackboardStore)
local AgentService = require(CompyServerScripts.World.AgentService)
local EnvironmentService = require(CompyServerScripts.World.EnvironmentService)
local MetricsService = require(CompyServerScripts.Services.MetricsService)
local Types = require(CompyServerScripts.Core.Types)
local VisualizationService = require(CompyServerScripts.Services.VisualizationService)

local Simulation = {}
Simulation.__index = Simulation

local DEBUG_REMOTES_FOLDER_NAME = "RemoteEvents"
local DEBUG_AVERAGE_FRAME_MS_REMOTE_NAME = "DebugAverageFrameMS"

local function getDebugAverageFrameMSRemote(): RemoteFunction
	local debugRemotesFolder = ReplicatedStorage:WaitForChild(DEBUG_REMOTES_FOLDER_NAME)
	local remote = debugRemotesFolder:WaitForChild(DEBUG_AVERAGE_FRAME_MS_REMOTE_NAME)
	assert(remote:IsA("RemoteFunction"), `{DEBUG_AVERAGE_FRAME_MS_REMOTE_NAME} must be a RemoteFunction`)

	return remote
end

function Simulation:_bindDebugRemoteFunctions(): ()
	self.debugAverageFrameMSRemote = getDebugAverageFrameMSRemote()
	self.debugAverageFrameMSRemote.OnServerInvoke = function(_player: Player): number
		return self.metrics:GetAverageFrameMS()
	end
end

function Simulation:_unbindDebugRemoteFunctions(): ()
	if not self.debugAverageFrameMSRemote then
		return
	end

	self.debugAverageFrameMSRemote.OnServerInvoke = function(_player: Player): nil
		return nil
	end
	self.debugAverageFrameMSRemote = nil
end

function Simulation:_createBlackboards(): ()
	for teamId in pairs(self.config.Teams) do
		self.blackboards[teamId] = BlackboardStore.new(teamId)
	end
end

function Simulation:_spawnAgents(): ()
	for teamId in pairs(self.config.Teams) do
		for index = 1, self.config.Simulation.DemoAgentsPerTeam do
			local id = ("%s_%02d"):format(teamId, index)
			local spawnCFrame = self.environment:GetSpawnCFrame(teamId, index)
			local state = AgentState.create(id, teamId, spawnCFrame.Position, spawnCFrame.LookVector, self.config)
			self.modelStore:CreateForAgent(state, spawnCFrame)

			local runtime = AgentRuntime.new({
				config = self.config,
				state = state,
				blackboard = self.blackboards[teamId],
				environment = self.environment,
				agentService = self.agentService,
				modelStore = self.modelStore,
			})

			self.agentService:Register(runtime)
			table.insert(self.runtimes, runtime)
		end
	end
end

function Simulation:Start(): ()
	if self.started then
		return
	end

	self.started = true
	self.environment:Refresh()
	self:_createBlackboards()
	self:_spawnAgents()

	self.visualization:Start()
	self.metrics:Start()
	self:_bindDebugRemoteFunctions()
	self.agentService:BindDebugRemotes()

	for _, runtime in ipairs(self.runtimes) do
		runtime:Start()
	end
end

function Simulation:Stop(): ()
	if not self.started then
		return
	end

	self.started = false
	self:_unbindDebugRemoteFunctions()
	self.agentService:UnbindDebugRemotes()

	for _, runtime in ipairs(self.runtimes) do
		runtime:Stop()
	end
	self.visualization:Stop()
	self.metrics:Stop()
	self.modelStore:DestroyAll()
end

function Simulation.new(config: Types.Config): Types.Simulation
	local self = setmetatable({}, Simulation)
	self.config = config
	self.started = false
	self.blackboards = {}
	self.runtimes = {}
	self.environment = EnvironmentService.new(config)
	self.agentService = AgentService.new()
	self.modelStore = AgentModelStore.new(config)
	self.visualization = VisualizationService.new(config, self.agentService)
	self.metrics = MetricsService.new(config, self.agentService)
	self.debugAverageFrameMSRemote = nil
	return self
end

return Simulation
