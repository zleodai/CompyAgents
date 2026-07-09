local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Types = require(CompyServerScripts.Core.Types)

local Action: Types.GOAPAction = {
	id = "HoldPosition",
	cost = 1,
	preconditions = {
		alive = true,
	},
	effects = {
		holding = true,
	},
	check = function(controller: Types.AgentController, context: Types.GOAPActionContext): boolean
		return controller:GetActionElapsed(context.now) >= 0.5
	end,
	start = function(controller: Types.AgentController, _context: Types.GOAPActionContext): ()
		controller:StopShooting()
	end,
}

return Action
