--[=[
	Intents

	Helpers for publishing short-lived tactical intent records. Intent claims let
	decentralized agents avoid duplicated roles without introducing a squad
	commander.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local Intents = {}

function Intents.PublishRole(
	blackboard: Types.BlackboardStore,
	agentId: Types.AgentId,
	role: string,
	target: string?,
	now: number,
	duration: number?
): ()
	blackboard:PublishIntent(agentId, {
		role = role,
		target = target,
	}, now, duration or 2)
end

return Intents
