local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Types = require(CompyServerScripts.Core.Types)

local Goal: Types.GOAPGoalDefinition = {
	id = "SearchEnemyPosition",
	check = function(_agentState: Types.AgentState, _blackboard: Types.BlackboardStore, facts: Types.FactMap): boolean
		return facts.hasVisibleEnemy == false and facts.knowsEnemyPosition == true
	end,
	priority = function(_agentState: Types.AgentState, _blackboard: Types.BlackboardStore, _facts: Types.FactMap): number
		return 50
	end,
	facts = function(_agentState: Types.AgentState, _blackboard: Types.BlackboardStore, _facts: Types.FactMap): Types.FactMap
		return {
			searchedEnemyPosition = true,
		}
	end,
}

return Goal
