--[=[
	TakeCover

	GOAP action that requests a cover movement position through AgentController
	and completes when MovementSystem records arrival.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local ACTION: Types.GOAPAction = {
	id = "TakeCover",
	cost = 1,
	preconditions = {
		alive = true,
	},
	effects = {
		inCover = true,
		exposed = false,
	},
	checkAction = function(controller: Types.AgentController, _context: Types.GOAPActionContext): boolean
		return controller:HasReachedDestination()
	end,
	onActionStart = function(controller: Types.AgentController, _context: Types.GOAPActionContext): ()
		controller:SetInCover(false)
		controller:MoveForAction("TakeCover")
	end,
	onActionUpdate = function(controller: Types.AgentController, _context: Types.GOAPActionContext): ()
		controller:MoveForAction("TakeCover")
	end,
	onActionEnd = function(controller: Types.AgentController, _context: Types.GOAPActionContext): ()
		controller:SetInCover(true)
	end,
}

return ACTION
