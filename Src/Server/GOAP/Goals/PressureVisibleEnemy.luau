--[=[
	PressureVisibleEnemy

	Goal definition that becomes available when an agent has a visible enemy and
	asks the planner to threaten that enemy.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local GOAL: Types.GOAPGoalDefinition = {
	id = "PressureVisibleEnemy",
	checkGoal = function(_agent: Types.Agent, _blackboard: Types.BlackboardStore, facts: Types.FactMap): boolean
		return facts.hasVisibleEnemy == true
	end,
	getPriority = function(_agent: Types.Agent, _blackboard: Types.BlackboardStore, _facts: Types.FactMap): number
		return 80
	end,
	getFacts = function(_agent: Types.Agent, _blackboard: Types.BlackboardStore, _facts: Types.FactMap): Types.FactMap
		return {
			enemyThreatened = true,
		}
	end,
}

return GOAL
