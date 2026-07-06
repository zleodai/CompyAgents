--[=[
	AgentStore

	Repository for all server-side agent data. Systems query this store by id,
	team, or ordered list rather than scanning Roblox Instances.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local AgentStore = {}
AgentStore.__index = AgentStore

function AgentStore:Add(agent: Types.Agent): boolean
	if self.byId[agent.id] then
		return false
	end

	self.byId[agent.id] = agent
	table.insert(self.ordered, agent)

	self.byTeam[agent.teamId] = self.byTeam[agent.teamId] or {}
	table.insert(self.byTeam[agent.teamId], agent)

	return true
end

function AgentStore:Get(agentId: Types.AgentId): Types.Agent?
	return self.byId[agentId]
end

function AgentStore:GetAll(): { Types.Agent }
	return self.ordered
end

function AgentStore:GetTeam(teamId: Types.TeamId): { Types.Agent }
	return self.byTeam[teamId] or {}
end

function AgentStore:ForEachAlive(callback: (Types.Agent) -> ()): ()
	for _, agent in ipairs(self.ordered) do
		if agent.stats.alive then
			callback(agent)
		end
	end
end

function AgentStore.new(): Types.AgentStore
	local self = setmetatable({}, AgentStore)

	self.byId = {}
	self.ordered = {}
	self.byTeam = {}

	return self
end

return AgentStore
