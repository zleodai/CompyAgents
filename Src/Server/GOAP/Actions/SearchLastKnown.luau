--[=[
	SearchLastKnown

	GOAP action that moves to the blackboard's best enemy sighting and completes
	after the movement request reaches that position.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local ACTION: Types.GOAPAction = {
	id = "SearchLastKnown",
	cost = 3,
	preconditions = {
		alive = true,
		enemyKnown = true,
	},
	effects = {
		searchedEnemyPosition = true,
	},
	checkAction = function(controller: Types.AgentController, _context: Types.GOAPActionContext): boolean
		return controller:HasReachedDestination()
	end,
	onActionStart = function(controller: Types.AgentController, _context: Types.GOAPActionContext): ()
		controller:MoveForAction("SearchLastKnown")
	end,
	onActionUpdate = function(controller: Types.AgentController, _context: Types.GOAPActionContext): ()
		controller:MoveForAction("SearchLastKnown")
	end,
	onActionEnd = function(_controller: Types.AgentController, _context: Types.GOAPActionContext): ()
	end,
}

return ACTION
