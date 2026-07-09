local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Types = require(CompyServerScripts.Core.Types)

local Action: Types.GOAPAction = {
	id = "AttackVisibleEnemy",
	cost = 1,
	preconditions = {
		alive = true,
		hasAmmo = true,
		hasVisibleEnemy = true,
	},
	effects = {
		enemyThreatened = true,
	},
	check = function(controller: Types.AgentController, _context: Types.GOAPActionContext): boolean
		return controller:HasCompletedShot()
	end,
	start = function(controller: Types.AgentController, context: Types.GOAPActionContext): ()
		controller:StopMovement()
		local target = controller:GetBestVisibleEnemy()
		if target then
			controller:LookAtPosition(target.position, context.dt)
			controller:ShootAtTarget(target.agentId)
		else
			controller:RequestPlan("attack_target_lost")
		end
	end,
	update = function(controller: Types.AgentController, context: Types.GOAPActionContext): ()
		local target = controller:GetBestVisibleEnemy()
		if target then
			controller:LookAtPosition(target.position, context.dt)
			controller:ShootAtTarget(target.agentId)
		else
			controller:StopShooting()
			controller:RequestPlan("attack_target_lost")
		end
	end,
	finish = function(controller: Types.AgentController, _context: Types.GOAPActionContext): ()
		controller:StopShooting()
	end,
}

return Action
