local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Types = require(CompyServerScripts.Core.Types)

local Goal: Types.GOAPGoalDefinition = {
	id = "PressureVisibleEnemy",
	check = function(_agentState: Types.AgentState, _blackboard: Types.BlackboardStore, facts: Types.FactMap): boolean
		return facts.hasVisibleEnemy == true and facts.hasAmmo == true
	end,
	priority = function(_agentState: Types.AgentState, _blackboard: Types.BlackboardStore, _facts: Types.FactMap): number
		return 80
	end,
	facts = function(_agentState: Types.AgentState, _blackboard: Types.BlackboardStore, _facts: Types.FactMap): Types.FactMap
		return {
			enemyThreatened = true,
		}
	end,
}

return Goal
