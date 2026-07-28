--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Types = require(CompyServerScripts.Core.Types)

local Actions = require(CompyServerScripts.GOAP.Actions)

local GOAPPlanner = {}

type Facts = { [string]: boolean }

type SearchNode = {
	facts: Facts,
	parent: SearchNode?,
	sourceAction: Types.Action?,
	cost: number,
	depth: number,
	sequence: number,
}

local function createEmptyPlan(): { Types.Action }
	return {}
end

local function factsSatisfied(facts: Facts, desiredFacts: Facts): boolean
	for key, value in pairs(desiredFacts) do
		if facts[key] ~= value then
			return false
		end
	end
	return true
end

local function applyEffects(facts: Facts, effects: Facts): Facts
	local nextFacts = table.clone(facts)
	for key, value in pairs(effects) do
		nextFacts[key] = value
	end
	return nextFacts
end

local function factsKey(facts: Facts): string
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

local function boundedStateKey(facts: Facts, depth: number): string
	return factsKey(facts) .. "#depth=" .. tostring(depth)
end

local function reconstructPlan(finalNode: SearchNode): { Types.Action }
	local reversed: { Types.Action } = {}
	local current = finalNode
	while current.parent do
		local sourceAction = current.sourceAction
		if not sourceAction then
			break
		end
		table.insert(reversed, sourceAction)
		current = current.parent
	end

	local plan = createEmptyPlan()
	for index = #reversed, 1, -1 do
		table.insert(plan, reversed[index])
	end
	return plan
end

local function combineGoalFacts(goal: Types.Goal): Facts?
	local goalFacts = table.clone(goal.activation)
	for key, value in pairs(goal.desired) do
		local activationValue = goalFacts[key]
		if activationValue ~= nil and activationValue ~= value then
			return nil
		end
		goalFacts[key] = value
	end
	return goalFacts
end

function GOAPPlanner.Plan(
	startFacts: Facts,
	goalFacts: Facts,
	actions: { Types.Action },
	options: { MaxExpansions: number?, MaxPlanDepth: number? }?
): {
	success: boolean,
	actions: { Types.Action },
	cost: number?,
	expansions: number,
	reason: string?,
}
	local maxExpansions = if options and options.MaxExpansions then options.MaxExpansions else 128
	local maxPlanDepth = if options and options.MaxPlanDepth then options.MaxPlanDepth else 6
	local startNode: SearchNode = {
		facts = table.clone(startFacts),
		parent = nil,
		sourceAction = nil,
		cost = 0,
		depth = 0,
		sequence = 0,
	}
	local frontier: { SearchNode } = { startNode }
	local bestCosts: { [string]: number } = {
		[boundedStateKey(startNode.facts, startNode.depth)] = 0,
	}
	local expansions = 0
	local nextSequence = 1

	while #frontier > 0 and expansions < maxExpansions do
		table.sort(frontier, function(a, b): boolean
			if a.cost == b.cost then
				return a.sequence < b.sequence
			end
			return a.cost < b.cost
		end)

		local node = table.remove(frontier, 1)
		if not node then
			break
		end
		local nodeKey = boundedStateKey(node.facts, node.depth)
		if node.cost > (bestCosts[nodeKey] or math.huge) then
			continue
		end

		expansions += 1

		if factsSatisfied(node.facts, goalFacts) then
			return {
				success = true,
				actions = reconstructPlan(node),
				cost = node.cost,
				expansions = expansions,
				reason = nil,
			}
		end

		if node.depth >= maxPlanDepth then
			continue
		end

		for _, action in ipairs(actions) do
			if factsSatisfied(node.facts, action.preconditions) then
				local nextFacts = applyEffects(node.facts, action.effects)
				if factsKey(nextFacts) == factsKey(node.facts) then
					continue
				end

				local nextDepth = node.depth + 1
				local nextCost = node.cost + action.cost
				local nextKey = boundedStateKey(nextFacts, nextDepth)
				if nextCost >= (bestCosts[nextKey] or math.huge) then
					continue
				end

				bestCosts[nextKey] = nextCost
				table.insert(frontier, {
					facts = nextFacts,
					parent = node,
					sourceAction = action,
					cost = nextCost,
					depth = nextDepth,
					sequence = nextSequence,
				})
				nextSequence += 1
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

function GOAPPlanner.MakePlan(
	beliefs: Facts,
	actionSet: { [string]: Types.Action },
	goalSet: { [string]: Types.Goal }
): {
	success: boolean,
	plan: { Types.Action },
	goal: Types.Goal?,
	cost: number?,
	expansions: number,
	reason: string?,
}
	local candidateGoals: { Types.Goal } = {}
	for _, goal in pairs(goalSet) do
		table.insert(candidateGoals, goal)
	end
	table.sort(candidateGoals, function(a, b): boolean
		if a.priority == b.priority then
			return a.id < b.id
		end
		return a.priority > b.priority
	end)
	local candidateActions = Actions.ToArray(actionSet)
	table.sort(candidateActions, function(a, b): boolean
		return a.id < b.id
	end)

	local totalExpansions = 0
	for _, goal in ipairs(candidateGoals) do
		local goalFacts = combineGoalFacts(goal)
		if not goalFacts then
			continue
		end

		local result = GOAPPlanner.Plan(beliefs, goalFacts, candidateActions, nil)
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

	return {
		success = false,
		plan = createEmptyPlan(),
		goal = nil,
		cost = nil,
		expansions = totalExpansions,
		reason = "No goal has a bounded plan",
	}
end

return GOAPPlanner
