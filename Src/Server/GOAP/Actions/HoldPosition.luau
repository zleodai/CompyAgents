--[=[
	HoldPosition

	GOAP action that intentionally waits for a short duration. PlanExecutor owns
	the timing through AgentDecision.actionRuntime.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local HOLD_DURATION = 0.35

local ACTION: Types.GOAPAction = {
	id = "HoldPosition",
	cost = 1,
	preconditions = {
		alive = true,
	},
	effects = {
		holding = true,
	},
	duration = HOLD_DURATION,
	checkAction = function(controller: Types.AgentController, context: Types.GOAPActionContext): boolean
		return controller:GetActionElapsed(context.now) >= HOLD_DURATION
	end,
	onActionStart = function(controller: Types.AgentController, _context: Types.GOAPActionContext): ()
		controller:StopShooting()
	end,
	onActionUpdate = function(_controller: Types.AgentController, _context: Types.GOAPActionContext): ()
	end,
	onActionEnd = function(_controller: Types.AgentController, _context: Types.GOAPActionContext): ()
	end,
}

return ACTION
