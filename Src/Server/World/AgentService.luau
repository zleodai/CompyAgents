--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Agent = require(CompyServerScripts.Agents.Agent)

local AgentService = {}
AgentService.__index = AgentService

type AgentRecord = {
	id: number,
	name: string,
	teamId: string,
	agent: Agent.Agent,
	character: Model,
}

type AgentServiceData = {
	recordsById: { [number]: AgentRecord },
	recordOrder: { AgentRecord },
	activeDebugAgentId: number?,
	debugActiveConnection: RBXScriptConnection?,
	debugTextRemote: RemoteFunction?,
}

export type AgentService = typeof(setmetatable({} :: AgentServiceData, AgentService))

function AgentService.Register(
	self: AgentService,
	id: number,
	name: string,
	teamId: string,
	agent: Agent.Agent,
	character: Model
): ()
	local record: AgentRecord = {
		id = id,
		name = name,
		teamId = teamId,
		agent = agent,
		character = character,
	}
	self.recordsById[id] = record
	table.insert(self.recordOrder, record)
end

function AgentService.GetRecord(self: AgentService, id: number): AgentRecord?
	return self.recordsById[id]
end

function AgentService.GetAllRecords(self: AgentService): { AgentRecord }
	return table.clone(self.recordOrder)
end

function AgentService.GetEnemyRecords(self: AgentService, teamId: string): { AgentRecord }
	local enemies: { AgentRecord } = {}
	for _, record in ipairs(self.recordOrder) do
		if record.teamId ~= teamId and record.agent.health > 0 then
			table.insert(enemies, record)
		end
	end
	return enemies
end

function AgentService.GetRecordFromDescendant(self: AgentService, instance: Instance): AgentRecord?
	for _, record in ipairs(self.recordOrder) do
		if instance:IsDescendantOf(record.character) then
			return record
		end
	end
	return nil
end

function AgentService.BindDebugRemotes(self: AgentService): ()
	local folder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not folder then
		return
	end

	local activeRemote = folder:FindFirstChild("DebugSetAgentInDepthDebugActive")
	if activeRemote and activeRemote:IsA("RemoteEvent") then
		self.debugActiveConnection = activeRemote.OnServerEvent:Connect(
			function(_player: Player, agentName: string, isActive: boolean): ()
				self.activeDebugAgentId = nil
				if not isActive then
					return
				end
				for _, record in ipairs(self.recordOrder) do
					if record.name == agentName then
						self.activeDebugAgentId = record.id
						break
					end
				end
			end
		)
	end

	local textRemote = folder:FindFirstChild("DebugGetAgentInDepthDebugText")
	if textRemote and textRemote:IsA("RemoteFunction") then
		self.debugTextRemote = textRemote
		textRemote.OnServerInvoke = function(_player: Player, agentName: string): string
			for _, record in ipairs(self.recordOrder) do
				if record.name == agentName then
					local action = record.agent.plannerState.goapAction
					local goal = record.agent.plannerState.goal
					local health = record.agent.controller:GetHumanoid().Health
					local ammo, _ = record.agent.controller:GetAmmo()
					return ("%s\nTeam: %s\nHealth: %.0f\nAmmo: %d\nGoal: %s\nAction: %s"):format(
						record.name,
						record.teamId,
						health,
						ammo,
						if goal then goal.id else "None",
						if action then action.id else "None"
					)
				end
			end
			return ""
		end
	end
end

function AgentService.UnbindDebugRemotes(self: AgentService): ()
	if self.debugActiveConnection then
		self.debugActiveConnection:Disconnect()
		self.debugActiveConnection = nil
	end
	if self.debugTextRemote then
		self.debugTextRemote.OnServerInvoke = function(): string
			return ""
		end
		self.debugTextRemote = nil
	end
	self.activeDebugAgentId = nil
end

function AgentService.DestroyAll(self: AgentService): ()
	self:UnbindDebugRemotes()
	for _, record in ipairs(self.recordOrder) do
		record.agent.endRuntime()
		record.character:Destroy()
	end
	table.clear(self.recordsById)
	table.clear(self.recordOrder)
end

function AgentService.new(): AgentService
	return setmetatable({
		recordsById = {},
		recordOrder = {},
		activeDebugAgentId = nil,
		debugActiveConnection = nil,
		debugTextRemote = nil,
	}, AgentService)
end

return AgentService
