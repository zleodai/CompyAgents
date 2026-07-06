--[=[
	Retreat

	GOAP action that moves away from the team's forward direction and marks the
	agent as in cover once MovementSystem records arrival.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local ACTION: Types.GOAPAction = {
	id = "Retreat",
	cost = 2,
	preconditions = {
		alive = true,
		lowHealth = true,
	},
	effects = {
		safe = true,
		inCover = true,
	},
	checkAction = function(controller: Types.AgentController, _context: Types.GOAPActionContext): boolean
		return controller:HasReachedDestination()
	end,
	onActionStart = function(controller: Types.AgentController, _context: Types.GOAPActionContext): ()
		controller:SetInCover(false)
		controller:MoveForAction("Retreat")
	end,
	onActionUpdate = function(controller: Types.AgentController, _context: Types.GOAPActionContext): ()
		controller:MoveForAction("Retreat")
	end,
	onActionEnd = function(controller: Types.AgentController, _context: Types.GOAPActionContext): ()
		controller:SetInCover(true)
	end,
}

return ACTION
