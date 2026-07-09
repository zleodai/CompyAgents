local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Types = require(CompyServerScripts.Core.Types)

local Action: Types.GOAPAction = {
	id = "Retreat",
	cost = 2,
	preconditions = {
		alive = true,
		lowHealth = true,
	},
	effects = {
		inCover = true,
	},
	check = function(controller: Types.AgentController, _context: Types.GOAPActionContext): boolean
		return controller:HasReachedDestination()
	end,
	start = function(controller: Types.AgentController, _context: Types.GOAPActionContext): ()
		controller:MoveForAction("Retreat")
	end,
	finish = function(controller: Types.AgentController, _context: Types.GOAPActionContext): ()
		controller:SetInCover(true)
	end,
}

return Action
