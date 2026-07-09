local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Types = require(CompyServerScripts.Core.Types)

local Action: Types.GOAPAction = {
	id = "AdvanceToEnemy",
	cost = 2,
	preconditions = {
		alive = true,
		knowsEnemyPosition = true,
	},
	effects = {
		hasVisibleEnemy = true,
	},
	check = function(controller: Types.AgentController, _context: Types.GOAPActionContext): boolean
		return controller:GetBestVisibleEnemy() ~= nil or controller:HasReachedDestination()
	end,
	start = function(controller: Types.AgentController, _context: Types.GOAPActionContext): ()
		controller:MoveForAction("AdvanceToEnemy")
	end,
	update = function(controller: Types.AgentController, _context: Types.GOAPActionContext): ()
		if controller:GetBestKnownEnemyPosition() == nil then
			controller:RequestPlan("advance_enemy_lost")
		end
	end,
}

return Action
