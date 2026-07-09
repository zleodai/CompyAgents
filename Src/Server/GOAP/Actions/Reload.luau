local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Types = require(CompyServerScripts.Core.Types)

local Action: Types.GOAPAction = {
	id = "Reload",
	cost = 1,
	preconditions = {
		hasAmmo = false,
		alive = true,
	},
	effects = {
		hasAmmo = true,
	},
	check = function(controller: Types.AgentController, _context: Types.GOAPActionContext): boolean
		return controller:HasCompletedReload()
	end,
	start = function(controller: Types.AgentController, _context: Types.GOAPActionContext): ()
		return controller:Reload()
	end,
}

return Action
