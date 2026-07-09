local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Types = require(CompyServerScripts.Core.Types)

local AgentMemory = {}
AgentMemory.__index = AgentMemory

function AgentMemory:RememberEnemy(agentId: string, position: Vector3, confidence: number, now: number): ()
	self.knownEnemies[agentId] = {
		agentId = agentId,
		position = position,
		confidence = confidence,
		lastSeenAt = now,
	}
end

function AgentMemory:GetBestKnownEnemy(): Types.PerceptionContact?
	local best = nil
	for _, enemy in pairs(self.knownEnemies) do
		if not best or enemy.confidence > best.confidence or enemy.lastSeenAt > best.lastSeenAt then
			best = enemy
		end
	end
	return best
end

function AgentMemory.new(): Types.AgentMemory
	local self = setmetatable({}, AgentMemory)
	self.knownEnemies = {}
	return self
end

return AgentMemory
