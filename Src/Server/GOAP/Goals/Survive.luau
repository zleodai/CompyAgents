--[=[
	Survive

	Goal definition that becomes available for low-health agents and asks the
	planner to reach a safe state.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local GOAL: Types.GOAPGoalDefinition = {
	id = "Survive",
	checkGoal = function(_agent: Types.Agent, _blackboard: Types.BlackboardStore, facts: Types.FactMap): boolean
		return facts.lowHealth == true
	end,
	getPriority = function(_agent: Types.Agent, _blackboard: Types.BlackboardStore, _facts: Types.FactMap): number
		return 0
	end,
	getFacts = function(_agent: Types.Agent, _blackboard: Types.BlackboardStore, _facts: Types.FactMap): Types.FactMap
		return {
			safe = true,
		}
	end,
}

return GOAL
