--[=[
	Actions

	Registry for modular GOAP action definitions. Each child module owns one
	action's planner metadata and runtime lifecycle functions.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local Actions = {}

local ACTIONS: { Types.GOAPAction } = {
	require(CompyServerScripts.GOAP.Actions.TakeCover),
	require(CompyServerScripts.GOAP.Actions.AdvanceToEnemy),
	require(CompyServerScripts.GOAP.Actions.AttackVisibleEnemy),
	require(CompyServerScripts.GOAP.Actions.SearchLastKnown),
	require(CompyServerScripts.GOAP.Actions.Retreat),
	require(CompyServerScripts.GOAP.Actions.HoldPosition),
}

function Actions.GetAll(): { Types.GOAPAction }
	return ACTIONS
end

function Actions.GetAvailableActions(
	_agent: Types.Agent?,
	_facts: Types.FactMap?,
	_blackboard: Types.BlackboardStore?
): { Types.GOAPAction }
	return ACTIONS
end

return Actions
