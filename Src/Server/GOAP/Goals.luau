--[=[
	Goals

	Builds GOAP facts and candidate goal records from agent state plus the
	team-local blackboard. This keeps goal selection separate from the planner.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local Goals = {}

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

function Goals.BuildCandidateGoals(agent: Types.Agent, blackboard: Types.BlackboardStore): { Types.GOAPGoal }
	local goals: { Types.GOAPGoal } = {}

	if agent.stats.health <= 35 then
		table.insert(goals, {
			id = "Survive",
			priority = 0,
			facts = {
				safe = true,
			},
		})
	end

	if #agent.perception.visibleEnemies > 0 then
		table.insert(goals, {
			id = "PressureVisibleEnemy",
			priority = 80,
			facts = {
				enemyThreatened = true,
			},
		})
	end

	if blackboard:GetBestEnemySighting() then
		table.insert(goals, {
			id = "SearchEnemyPosition",
			priority = 50,
			facts = {
				searchedEnemyPosition = true,
			},
		})
	end

	table.insert(goals, {
		id = "Hold",
		priority = 10,
		facts = {
			holding = true,
		},
	})

	table.sort(goals, function(a: Types.GOAPGoal, b: Types.GOAPGoal): boolean
		return a.priority > b.priority
	end)

	return goals
end

return Goals
