local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Types = require(CompyServerScripts.Core.Types)

local AgentService = {}
AgentService.__index = AgentService

local DEBUG_REMOTES_FOLDER_NAME = "RemoteEvents"
local DEBUG_SET_IN_DEPTH_ACTIVE_REMOTE_NAME = "DebugSetAgentInDepthDebugActive"
local DEBUG_GET_IN_DEPTH_TEXT_REMOTE_NAME = "DebugGetAgentInDepthDebugText"

local function getDebugRemoteEvent(name: string): RemoteEvent
	local debugRemotesFolder = ReplicatedStorage:WaitForChild(DEBUG_REMOTES_FOLDER_NAME)
	local remote = debugRemotesFolder:WaitForChild(name)
	assert(remote:IsA("RemoteEvent"), `{name} must be a RemoteEvent`)

	return remote
end

local function getDebugRemoteFunction(name: string): RemoteFunction
	local debugRemotesFolder = ReplicatedStorage:WaitForChild(DEBUG_REMOTES_FOLDER_NAME)
	local remote = debugRemotesFolder:WaitForChild(name)
	assert(remote:IsA("RemoteFunction"), `{name} must be a RemoteFunction`)

	return remote
end

function AgentService:Register(runtime: Types.AgentRuntime): ()
	self.runtimes[runtime.state.id] = runtime
	table.insert(self.runtimeOrder, runtime)
end

function AgentService:GetRuntime(agentId: string): Types.AgentRuntime?
	return self.runtimes[agentId]
end

function AgentService:GetState(agentId: string): Types.AgentState?
	local runtime = self.runtimes[agentId]
	return runtime and runtime.state or nil
end

function AgentService:GetAllRuntimes(): { Types.AgentRuntime }
	return table.clone(self.runtimeOrder)
end

function AgentService:GetTeamStates(teamId: string): { Types.AgentState }
	local result = {}
	for _, runtime in ipairs(self.runtimeOrder) do
		if runtime.state.teamId == teamId then
			table.insert(result, runtime.state)
		end
	end
	return result
end

function AgentService:GetEnemyStates(teamId: string): { Types.AgentState }
	local result = {}
	for _, runtime in ipairs(self.runtimeOrder) do
		if runtime.state.teamId ~= teamId and runtime.state.alive then
			table.insert(result, runtime.state)
		end
	end
	return result
end

function AgentService:BroadcastToTeam(teamId: string, event: Types.AgentEvent): ()
	for _, runtime in ipairs(self.runtimeOrder) do
		if runtime.state.teamId == teamId then
			runtime:PushEvent(event)
		end
	end
end

function AgentService:SetInDepthDebugUIActive(agentId: string, isActive: boolean): ()
	local state = self:GetState(agentId)
	if not state then
		return
	end

	if isActive then
		if self.activeInDepthDebugAgentId and self.activeInDepthDebugAgentId ~= agentId then
			local previousState = self:GetState(self.activeInDepthDebugAgentId)
			if previousState then
				previousState.inDepthDebugUIActive = false
			end
		end

		state.inDepthDebugUIActive = true
		self.activeInDepthDebugAgentId = agentId
	else
		state.inDepthDebugUIActive = false
		if self.activeInDepthDebugAgentId == agentId then
			self.activeInDepthDebugAgentId = nil
		end
	end
end

function AgentService:GetInDepthDebugUIText(agentId: string): string
	local state = self:GetState(agentId)
	if not state or not state.inDepthDebugUIActive then
		return ""
	end

	return state.inDepthDebugUIText
end

function AgentService:BindDebugRemotes(): ()
	self.inDepthDebugTextRemote = getDebugRemoteFunction(DEBUG_GET_IN_DEPTH_TEXT_REMOTE_NAME)
	self.inDepthDebugTextRemote.OnServerInvoke = function(_player: Player, agentId: string): string
		if typeof(agentId) ~= "string" then
			return ""
		end

		return self:GetInDepthDebugUIText(agentId)
	end

	self.inDepthDebugActiveRemote = getDebugRemoteEvent(DEBUG_SET_IN_DEPTH_ACTIVE_REMOTE_NAME)
	self.inDepthDebugActiveConnection = self.inDepthDebugActiveRemote.OnServerEvent:Connect(
		function(_player: Player, agentId: string, isActive: boolean): ()
			if typeof(agentId) ~= "string" or typeof(isActive) ~= "boolean" then
				return
			end

			self:SetInDepthDebugUIActive(agentId, isActive)
		end
	)
end

function AgentService:UnbindDebugRemotes(): ()
	if self.inDepthDebugActiveConnection then
		self.inDepthDebugActiveConnection:Disconnect()
		self.inDepthDebugActiveConnection = nil
	end

	if self.inDepthDebugTextRemote then
		self.inDepthDebugTextRemote.OnServerInvoke = function(_player: Player, _agentId: string): string
			return ""
		end
		self.inDepthDebugTextRemote = nil
	end

	if self.activeInDepthDebugAgentId then
		local activeState = self:GetState(self.activeInDepthDebugAgentId)
		if activeState then
			activeState.inDepthDebugUIActive = false
		end
		self.activeInDepthDebugAgentId = nil
	end

	self.inDepthDebugActiveRemote = nil
end

function AgentService.new(): Types.AgentService
	local self = setmetatable({}, AgentService)
	self.runtimes = {}
	self.runtimeOrder = {}
	self.activeInDepthDebugAgentId = nil
	self.inDepthDebugTextRemote = nil
	self.inDepthDebugActiveRemote = nil
	self.inDepthDebugActiveConnection = nil
	return self
end

return AgentService
