local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Types = require(CompyServerScripts.Core.Types)

local Intents = {}

function Intents.Publish(
	blackboard: Types.BlackboardStore,
	agentId: string,
	intent: Types.IntentData,
	now: number,
	duration: number
): ()
	blackboard:PublishIntent(agentId, intent, now, duration)
end

return Intents
