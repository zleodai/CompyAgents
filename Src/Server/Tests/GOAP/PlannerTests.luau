local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Planner = require(CompyServerScripts.GOAP.Planner)
local Types = require(CompyServerScripts.Core.Types)

local PlannerTests: { Types.TestCase } = {}

table.insert(PlannerTests, {
	name = "Planner returns bounded plan that satisfies facts",
	run = function(context: Types.TestContext): ()
		local actions: { Types.GOAPAction } = {
			{
				id = "FindEnemy",
				cost = 1,
				preconditions = {
					alive = true,
				},
				effects = {
					knowsEnemyPosition = true,
				},
			},
			{
				id = "AttackVisibleEnemy",
				cost = 1,
				preconditions = {
					knowsEnemyPosition = true,
				},
				effects = {
					enemyThreatened = true,
				},
			},
		}

		local result = Planner.Plan({
			alive = true,
			knowsEnemyPosition = false,
			enemyThreatened = false,
		}, {
			enemyThreatened = true,
		}, actions, {
			MaxExpansions = 16,
			MaxPlanDepth = 4,
		})

		context.Assert(result.success, "planner should find a plan")
		context.AssertEqual(#result.actions, 2, "planner should return two actions")
		context.AssertEqual(result.actions[1].id, "FindEnemy", "planner should preserve action order")
	end,
})

return PlannerTests
