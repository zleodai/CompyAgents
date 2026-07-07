--[=[
	SearchEnemyPosition

	Goal definition that becomes available when the team blackboard has a known
	enemy sighting and asks the planner to search that position.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local GOAL: Types.GOAPGoalDefinition = {
	id = "SearchEnemyPosition",
	checkGoal = function(_agent: Types.Agent, blackboard: Types.BlackboardStore, _facts: Types.FactMap): boolean
		return blackboard:GetBestEnemySighting() ~= nil
	end,
	getPriority = function(_agent: Types.Agent, _blackboard: Types.BlackboardStore, _facts: Types.FactMap): number
		return 50
	end,
	getFacts = function(_agent: Types.Agent, _blackboard: Types.BlackboardStore, _facts: Types.FactMap): Types.FactMap
		return {
			searchedEnemyPosition = true,
		}
	end,
}

return GOAL
