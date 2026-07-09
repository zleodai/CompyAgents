local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Types = require(CompyServerScripts.Core.Types)

local Actions: { Types.GOAPAction } = {
	require(CompyServerScripts.GOAP.Actions.TakeCover),
	require(CompyServerScripts.GOAP.Actions.AdvanceToEnemy),
	require(CompyServerScripts.GOAP.Actions.AttackVisibleEnemy),
	require(CompyServerScripts.GOAP.Actions.SearchLastKnown),
	require(CompyServerScripts.GOAP.Actions.Reload),
	require(CompyServerScripts.GOAP.Actions.Retreat),
	require(CompyServerScripts.GOAP.Actions.HoldPosition),
}

return Actions
