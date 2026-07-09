local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Types = require(CompyServerScripts.Core.Types)

local Planner = {}

local function goalSatisfied(facts: Types.FactMap, goalFacts: Types.FactMap): boolean
	for key, value in pairs(goalFacts) do
		if facts[key] ~= value then
			return false
		end
	end
	return true
end

local function preconditionsMet(facts: Types.FactMap, preconditions: Types.FactMap): boolean
	for key, value in pairs(preconditions) do
		if facts[key] ~= value then
			return false
		end
	end
	return true
end

local function applyEffects(facts: Types.FactMap, effects: Types.FactMap): Types.FactMap
	local nextFacts = table.clone(facts)
	for key, value in pairs(effects) do
		nextFacts[key] = value
	end
	return nextFacts
end

local function factsKey(facts: Types.FactMap): string
	local keys = {}
	for key in pairs(facts) do
		table.insert(keys, key)
	end
	table.sort(keys)

	local parts = {}
	for _, key in ipairs(keys) do
		table.insert(parts, key .. "=" .. tostring(facts[key]))
	end
	return table.concat(parts, "|")
end

local Shared = game:GetService("ReplicatedStorage")
local Util = require(Shared.Packages.Util)

function Planner.Plan(
	startFacts: Types.FactMap,
	goalFacts: Types.FactMap,
	actions: { Types.GOAPAction },
	options: Types.PlannerOptions
): Types.PlanResult
	local maxExpansions = options.MaxExpansions or 128
	local maxPlanDepth = options.MaxPlanDepth or 6
	local frontier = {
		{
			facts = startFacts,
			plan = {},
			cost = 0,
		},
	}
	local visited = {}
	local expansions = 0

	while #frontier > 0 and expansions < maxExpansions do
		table.sort(frontier, function(a: Types.PlannerNode, b: Types.PlannerNode): boolean
			return a.cost < b.cost
		end)

		local node = table.remove(frontier, 1)
		local key = factsKey(node.facts)
		if visited[key] then
			continue
		end

		visited[key] = true
		expansions += 1

		if goalSatisfied(node.facts, goalFacts) then
			return {
				success = true,
				actions = node.plan,
				cost = node.cost,
				expansions = expansions,
			}
		end

		if #node.plan >= maxPlanDepth then
			continue
		end

		for _, action in ipairs(actions) do
			if preconditionsMet(node.facts, action.preconditions) then
				local nextPlan = table.clone(node.plan)
				table.insert(nextPlan, action)
				table.insert(frontier, {
					facts = applyEffects(node.facts, action.effects),
					plan = nextPlan,
					cost = node.cost + (action.cost or 1),
				})
			end
		end
	end

	return {
		success = false,
		reason = "No bounded plan found",
		expansions = expansions,
	}
end

return Planner
