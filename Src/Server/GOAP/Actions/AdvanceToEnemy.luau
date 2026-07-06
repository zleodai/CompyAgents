--[=[
	AdvanceToEnemy

	GOAP action that moves toward a known enemy position. Destination resolution
	comes from the active world-query adapter through AgentController.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local ACTION: Types.GOAPAction = {
	id = "AdvanceToEnemy",
	cost = 2,
	preconditions = {
		alive = true,
		enemyKnown = true,
	},
	effects = {
		inRange = true,
	},
	checkAction = function(controller: Types.AgentController, _context: Types.GOAPActionContext): boolean
		return controller:HasReachedDestination()
	end,
	onActionStart = function(controller: Types.AgentController, _context: Types.GOAPActionContext): ()
		controller:SetInCover(false)
		controller:MoveForAction("AdvanceToEnemy")
	end,
	onActionUpdate = function(controller: Types.AgentController, _context: Types.GOAPActionContext): ()
		controller:MoveForAction("AdvanceToEnemy")
	end,
	onActionEnd = function(_controller: Types.AgentController, _context: Types.GOAPActionContext): ()
	end,
}

return ACTION
