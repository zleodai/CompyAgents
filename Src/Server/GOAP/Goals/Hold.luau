--[=[
	Hold

	Default fallback goal definition. It is always available and asks the planner
	to hold position when no stronger goal can produce a plan.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local GOAL: Types.GOAPGoalDefinition = {
	id = "Hold",
	checkGoal = function(_agent: Types.Agent, _blackboard: Types.BlackboardStore, _facts: Types.FactMap): boolean
		return true
	end,
	getPriority = function(_agent: Types.Agent, _blackboard: Types.BlackboardStore, _facts: Types.FactMap): number
		return 10
	end,
	getFacts = function(_agent: Types.Agent, _blackboard: Types.BlackboardStore, _facts: Types.FactMap): Types.FactMap
		return {
			holding = true,
		}
	end,
}

return GOAL
