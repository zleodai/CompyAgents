--!strict

local Action = {
	id = "FindEnemyLocation",
	cost = 1,
	preconditions = {
		hasEnemyPos = false,
	},
	effects = {
		hasEnemyPos = true,
	},
}

function Action.Start<Agent>(_agent: Agent): () end

function Action.Update<Agent>(_agent: Agent, _dt: number): () end

function Action.FinishedCheck<Agent>(agent: Agent & { sightedEnemyLocs: { Vector3 } }): boolean
	return #agent.sightedEnemyLocs > 0
end

function Action.End<Agent>(_agent: Agent): () end

return Action
