--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CompyServerScripts = ServerScriptService.CompyAgent
local CompySharedScripts = ReplicatedStorage.CompyAgent

local AgentService = require(CompyServerScripts.Services.AgentService)
local Config = require(CompySharedScripts.Config)

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local DebugSetAgentInDepthDebugActive = RemoteEvents.DebugSetAgentInDepthDebugActive
local DebugGetAgentInDepthDebugText = RemoteEvents.DebugGetAgentInDepthDebugText

local DebugService = {}
DebugService.__index = DebugService

type DebugServiceData = {
	config: typeof(Config.Simulation.DebugService),
	agentService: AgentService.AgentService,
	running: boolean,
	selectedAgentConnection: RBXScriptConnection?,
	selectedAgent: string?,
}

export type DebugService = typeof(setmetatable({} :: DebugServiceData, DebugService))

function DebugService.Start(self: DebugService): ()
	if self.running then
		return
	end

	self.running = true

	self.selectedAgentConnection = DebugSetAgentInDepthDebugActive.OnServerEvent:Connect(function(_, name)
		self.selectedAgent = name
	end)
	DebugGetAgentInDepthDebugText.OnServerInvoke = function(_, name): string
		if self.selectedAgent == nil then
			return "No Agent Selected"
		end

		local agent = self.agentService:GetAgentByName(name)

		if agent == nil then
			return `{name} not a valid agent`
		end

		local agentDump = agent:DebugDump()
		local plannerDump = ""

		if self.config.PlannerLogsEnabled then
			plannerDump = agent.planner:DebugDump()
		end

		return plannerDump .. "\n" .. agentDump
	end
end

function DebugService.End(self: DebugService): ()
	self.running = false

	if self.selectedAgentConnection then
		self.selectedAgentConnection:Disconnect()
		self.selectedAgentConnection = nil
	end
	DebugGetAgentInDepthDebugText.OnServerInvoke = nil
	self.selectedAgent = nil
end

local singleton: DebugService = setmetatable({
	config = Config.Simulation.DebugService,
	agentService = AgentService,
	running = false,
	heartbeatConnection = nil,
	selectedAgentConnection = nil,
	selectedAgent = nil,
}, DebugService)

return singleton
