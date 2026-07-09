local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Types = require(CompyServerScripts.Core.Types)

local GoalDefinitions: { Types.GOAPGoalDefinition } = {
	-- require(CompyServerScripts.GOAP.Goals.Survive),
	require(CompyServerScripts.GOAP.Goals.PressureVisibleEnemy),
	require(CompyServerScripts.GOAP.Goals.SearchEnemyPosition),
	require(CompyServerScripts.GOAP.Goals.Hold),
}

local Goals = {}

function Goals.BuildFacts(
	agentState: Types.AgentState,
	blackboard: Types.BlackboardStore,
	environment: Types.EnvironmentService
): Types.FactMap
	local healthRatio = agentState.health / 100
	local bestSighting = blackboard:GetBestEnemySighting()
	local coverPosition = environment:GetNearestCover(agentState.position, agentState.teamId)

	return {
		alive = agentState.alive,
		hasAmmo = agentState.ammo > 0,
		lowHealth = healthRatio <= 0.35,
		hasVisibleEnemy = #agentState.visibleEnemies > 0,
		knowsEnemyPosition = bestSighting ~= nil or next(agentState.knownEnemies) ~= nil,
		hasCover = coverPosition ~= nil,
		inCover = agentState.inCover == true,
		enemyThreatened = false,
		searchedEnemyPosition = false,
		holding = false,
	}
end

function Goals.BuildCandidateGoals(
	agentState: Types.AgentState,
	blackboard: Types.BlackboardStore,
	facts: Types.FactMap
): { Types.GOAPGoal }
	local goals = {}

	for _, definition in ipairs(GoalDefinitions) do
		table.insert(goals, {
			id = definition.id,
			priority = definition.priority(agentState, blackboard, facts),
			facts = definition.facts(agentState, blackboard, facts),
		})
	end

	table.sort(goals, function(a: Types.GOAPGoal, b: Types.GOAPGoal): boolean
		return a.priority > b.priority
	end)

	return goals
end

return Goals
