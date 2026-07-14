--!strict

local Action = {
	id = "FindObjective",
	cost = 1,
	preconditions = {
		hasObjectivePos = false,
	},
	effects = {
		hasObjectivePos = true,
	},
}

function Action.Start<Agent>(_agent: Agent): () end

function Action.Update<Agent>(_agent: Agent, _dt: number): () end

function Action.FinishedCheck<Agent>(agent: Agent & { sightedObjectiveLocs: { Vector3 } }): boolean
	return #agent.sightedObjectiveLocs > 0
end

function Action.End<Agent>(_agent: Agent): () end

return Action
