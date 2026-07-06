--[=[
	AttackVisibleEnemy

	GOAP action that requests one abstract shot against the best visible enemy.
	CombatSystem performs the shot from AgentCombat data and marks completion.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local ACTION: Types.GOAPAction = {
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
	checkAction = function(controller: Types.AgentController, _context: Types.GOAPActionContext): boolean
		return controller:HasCompletedShot()
	end,
	onActionStart = function(controller: Types.AgentController, context: Types.GOAPActionContext): ()
		local target = controller:GetBestVisibleEnemy()
		if target then
			controller:ShootAtTarget(target.agentId)
		else
			controller:RequestPlan(context.now, "attack_target_lost")
		end
	end,
	onActionUpdate = function(controller: Types.AgentController, context: Types.GOAPActionContext): ()
		local target = controller:GetBestVisibleEnemy()
		if target then
			controller:ShootAtTarget(target.agentId)
		else
			controller:StopShooting()
			controller:RequestPlan(context.now, "attack_target_lost")
		end
	end,
	onActionEnd = function(controller: Types.AgentController, _context: Types.GOAPActionContext): ()
		controller:StopShooting()
	end,
}

return ACTION
