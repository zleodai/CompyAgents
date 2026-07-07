--[=[
	GOAPPlannerTests

	Verifies that the symbolic planner chooses the expected action sequence for
	the current core goal set and a lower-cost choice when alternatives exist.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)
local Actions = require(CompyServerScripts.GOAP.Actions)
local Planner = require(CompyServerScripts.GOAP.Planner)

local GOAPPlannerTests: { Types.TestCase } = {}

local PLANNER_OPTIONS: Types.PlannerOptions = {
	MaxExpansions = 128,
	MaxPlanDepth = 6,
	ReplanCooldown = 0.75,
	FailedPlanCooldown = 1.25,
}

local function collectActionIds(plan: Types.GOAPPlan): { Types.ActionId }
	local actionIds: { Types.ActionId } = {}

	for _, action in ipairs(plan) do
		table.insert(actionIds, action.id)
	end

	return actionIds
end

local function assertPlan(
	context: Types.TestContext,
	startFacts: Types.FactMap,
	goalFacts: Types.FactMap,
	expectedActionIds: { Types.ActionId },
	expectedCost: number,
	message: string
): ()
	local result = Planner.Plan(startFacts, goalFacts, Actions.GetAll(), PLANNER_OPTIONS)
	context.Assert(result.success, message .. " should produce a successful plan")
	context.AssertEqual(result.cost, expectedCost, message .. " should have expected cost")

	local plan = result.actions
	context.Assert(plan ~= nil, message .. " should return actions")
	if not plan then
		return
	end

	context.AssertActionSequence(collectActionIds(plan), expectedActionIds, message)
end

table.insert(GOAPPlannerTests, {
	name = "GOAP planner chooses Retreat for Survive goal",
	run = function(context: Types.TestContext): ()
		assertPlan(context, {
			alive = true,
			hasAmmo = true,
			lowHealth = true,
			hasVisibleEnemy = true,
			enemyKnown = true,
			inCover = false,
			exposed = true,
			inRange = true,
		}, {
			safe = true,
		}, {
			"Retreat",
		}, 2, "Survive goal")
	end,
})

table.insert(GOAPPlannerTests, {
	name = "GOAP planner chooses AttackVisibleEnemy for PressureVisibleEnemy goal",
	run = function(context: Types.TestContext): ()
		assertPlan(context, {
			alive = true,
			hasAmmo = true,
			lowHealth = false,
			hasVisibleEnemy = true,
			enemyKnown = true,
			inCover = false,
			exposed = true,
			inRange = true,
		}, {
			enemyThreatened = true,
		}, {
			"AttackVisibleEnemy",
		}, 1, "PressureVisibleEnemy goal")
	end,
})

table.insert(GOAPPlannerTests, {
	name = "GOAP planner chooses SearchLastKnown for SearchEnemyPosition goal",
	run = function(context: Types.TestContext): ()
		assertPlan(context, {
			alive = true,
			hasAmmo = true,
			lowHealth = false,
			hasVisibleEnemy = false,
			enemyKnown = true,
			inCover = false,
			exposed = true,
			inRange = false,
		}, {
			searchedEnemyPosition = true,
		}, {
			"SearchLastKnown",
		}, 3, "SearchEnemyPosition goal")
	end,
})

table.insert(GOAPPlannerTests, {
	name = "GOAP planner chooses HoldPosition for Hold goal",
	run = function(context: Types.TestContext): ()
		assertPlan(context, {
			alive = true,
			hasAmmo = true,
			lowHealth = false,
			hasVisibleEnemy = false,
			enemyKnown = false,
			inCover = false,
			exposed = true,
			inRange = false,
		}, {
			holding = true,
		}, {
			"HoldPosition",
		}, 1, "Hold goal")
	end,
})

table.insert(GOAPPlannerTests, {
	name = "GOAP planner chooses lower cost TakeCover over Retreat for cover-only goal",
	run = function(context: Types.TestContext): ()
		assertPlan(context, {
			alive = true,
			hasAmmo = true,
			lowHealth = true,
			hasVisibleEnemy = false,
			enemyKnown = false,
			inCover = false,
			exposed = true,
			inRange = false,
		}, {
			inCover = true,
		}, {
			"TakeCover",
		}, 1, "Cover-only goal")
	end,
})

return GOAPPlannerTests
