local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Types = require(CompyServerScripts.Core.Types)

local Goal: Types.GOAPGoalDefinition = {
	id = "Survive",
	check = function(_agentState: Types.AgentState, _blackboard: Types.BlackboardStore, facts: Types.FactMap): boolean
		return facts.lowHealth == true
	end,
	priority = function(_agentState: Types.AgentState, _blackboard: Types.BlackboardStore, _facts: Types.FactMap): number
		return 100
	end,
	facts = function(_agentState: Types.AgentState, _blackboard: Types.BlackboardStore, _facts: Types.FactMap): Types.FactMap
		return {
			inCover = true,
		}
	end,
}

return Goal
