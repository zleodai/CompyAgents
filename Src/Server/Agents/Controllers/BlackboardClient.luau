local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Types = require(CompyServerScripts.Core.Types)

local BlackboardClient = {}
BlackboardClient.__index = BlackboardClient

function BlackboardClient:PublishPosition(now: number): ()
	self.blackboard:RecordTeammatePosition(self.state.id, self.state.position, now)
end

function BlackboardClient:PublishDeath(now: number): ()
	self.blackboard:RecordTeammateDeath(self.state.id, self.state.position, now)
end

function BlackboardClient:PublishEnemySighting(
	agentId: string,
	position: Vector3,
	confidence: number,
	confirmed: boolean,
	now: number
): ()
	self.blackboard:RecordEnemySighting(agentId, position, confidence, confirmed, now)
end

function BlackboardClient:PublishIntent(kind: string, data: { [string]: Types.FactValue }, now: number): ()
	self.blackboard:PublishIntent(self.state.id, {
		kind = kind,
		data = data,
	}, now, 1.5)
end

function BlackboardClient:Reserve(resourceId: string, now: number, duration: number): boolean
	return self.blackboard:Reserve(resourceId, self.state.id, now, duration)
end

function BlackboardClient:Cleanup(now: number): ()
	self.blackboard:Cleanup(now)
end

function BlackboardClient.new(runtime: Types.AgentRuntime): Types.BlackboardClient
	local self = setmetatable({}, BlackboardClient)
	self.runtime = runtime
	self.state = runtime.state
	self.blackboard = runtime.blackboard
	return self
end

return BlackboardClient
