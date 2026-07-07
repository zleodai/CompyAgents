--[=[
	Goals

	Registry for modular GOAP goal definitions. Each child module owns one
	goal's availability, priority, and planner target facts.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local Goals = {}

local GOALS: { Types.GOAPGoalDefinition } = {
	require(CompyServerScripts.GOAP.Goals.Survive),
	require(CompyServerScripts.GOAP.Goals.PressureVisibleEnemy),
	require(CompyServerScripts.GOAP.Goals.SearchEnemyPosition),
	require(CompyServerScripts.GOAP.Goals.Hold),
}

function Goals.BuildFacts(agent: Types.Agent, blackboard: Types.BlackboardStore): Types.FactMap
	local visibleCount = #agent.perception.visibleEnemies
	local bestSighting = blackboard:GetBestEnemySighting()

	return {
		alive = agent.stats.alive,
		hasAmmo = agent.stats.ammo > 0,
		lowHealth = agent.stats.health <= 35,
		hasVisibleEnemy = visibleCount > 0,
		enemyKnown = visibleCount > 0 or bestSighting ~= nil,
		inCover = agent.tactical.inCover,
		exposed = not agent.tactical.inCover,
		inRange = visibleCount > 0,
	}
end

function Goals.GetAll(): { Types.GOAPGoalDefinition }
	return GOALS
end

function Goals.BuildCandidateGoals(
	agent: Types.Agent,
	blackboard: Types.BlackboardStore,
	factsOverride: Types.FactMap?
): { Types.GOAPGoal }
	local facts = factsOverride or Goals.BuildFacts(agent, blackboard)
	local goals: { Types.GOAPGoal } = {}

	for _, goalDefinition in ipairs(GOALS) do
		if goalDefinition.checkGoal(agent, blackboard, facts) then
			table.insert(goals, {
				id = goalDefinition.id,
				priority = goalDefinition.getPriority(agent, blackboard, facts),
				facts = goalDefinition.getFacts(agent, blackboard, facts),
			})
		end
	end

	table.sort(goals, function(a: Types.GOAPGoal, b: Types.GOAPGoal): boolean
		return a.priority > b.priority
	end)

	return goals
end

return Goals
