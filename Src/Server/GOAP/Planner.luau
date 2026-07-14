--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Actions = require(CompyServerScripts.GOAP.Actions)
local Goals = require(CompyServerScripts.GOAP.Goals)

local Planner = {}

local function createEmptyPlan(): typeof(Actions)
	local plan = table.clone(Actions)
	table.clear(plan)
	return plan
end

local function factsSatisfied(facts: { [string]: boolean }, desiredFacts: { [string]: boolean }): boolean
	for key, value in pairs(desiredFacts) do
		if facts[key] ~= value then
			return false
		end
	end
	return true
end

local function applyEffects(facts: { [string]: boolean }, effects: { [string]: boolean }): { [string]: boolean }
	local nextFacts = table.clone(facts)
	for key, value in pairs(effects) do
		nextFacts[key] = value
	end
	return nextFacts
end

local function factsKey(facts: { [string]: boolean }): string
	local keys: { string } = {}
	for key in pairs(facts) do
		table.insert(keys, key)
	end
	table.sort(keys)

	local parts: { string } = {}
	for _, key in ipairs(keys) do
		table.insert(parts, key .. "=" .. tostring(facts[key]))
	end
	return table.concat(parts, "|")
end

function Planner.Plan(
	startFacts: { [string]: boolean },
	goalFacts: { [string]: boolean },
	actions: typeof(Actions),
	options: { MaxExpansions: number?, MaxPlanDepth: number? }?
): {
	success: boolean,
	actions: typeof(Actions),
	cost: number?,
	expansions: number,
	reason: string?,
}
	local maxExpansions = if options and options.MaxExpansions then options.MaxExpansions else 128
	local maxPlanDepth = if options and options.MaxPlanDepth then options.MaxPlanDepth else 6
	local frontier: {
		{
			facts: { [string]: boolean },
			plan: typeof(Actions),
			cost: number,
		}
	} = {
		{
			facts = table.clone(startFacts),
			plan = createEmptyPlan(),
			cost = 0,
		},
	}
	local visited: { [string]: boolean } = {}
	local expansions = 0

	while #frontier > 0 and expansions < maxExpansions do
		table.sort(frontier, function(a, b): boolean
			return a.cost < b.cost
		end)

		local node = table.remove(frontier, 1)
		if not node then
			break
		end
		local key = factsKey(node.facts)
		if visited[key] then
			continue
		end

		visited[key] = true
		expansions += 1

		if factsSatisfied(node.facts, goalFacts) then
			return {
				success = true,
				actions = node.plan,
				cost = node.cost,
				expansions = expansions,
				reason = nil,
			}
		end

		if #node.plan >= maxPlanDepth then
			continue
		end

		for _, action in ipairs(actions) do
			if factsSatisfied(node.facts, action.preconditions) then
				local nextPlan = table.clone(node.plan)
				table.insert(nextPlan, action)
				table.insert(frontier, {
					facts = applyEffects(node.facts, action.effects),
					plan = nextPlan,
					cost = node.cost + action.cost,
				})
			end
		end
	end

	return {
		success = false,
		actions = createEmptyPlan(),
		cost = nil,
		expansions = expansions,
		reason = "No bounded plan found",
	}
end

function Planner.MakePlan(beliefs: { [string]: boolean }): {
	success: boolean,
	plan: typeof(Actions),
	goal: typeof(Goals[1])?,
	cost: number?,
	expansions: number,
	reason: string?,
}
	local candidateGoals = table.clone(Goals)
	table.sort(candidateGoals, function(a, b): boolean
		return a.priority > b.priority
	end)

	local totalExpansions = 0
	for _, goal in ipairs(candidateGoals) do
		if factsSatisfied(beliefs, goal.activation) then
			local result = Planner.Plan(beliefs, goal.desired, Actions, nil)
			totalExpansions += result.expansions
			if result.success then
				return {
					success = true,
					plan = result.actions,
					goal = goal,
					cost = result.cost,
					expansions = totalExpansions,
					reason = nil,
				}
			end
		end
	end

	return {
		success = false,
		plan = createEmptyPlan(),
		goal = nil,
		cost = nil,
		expansions = totalExpansions,
		reason = "No active goal has a bounded plan",
	}
end

return Planner
