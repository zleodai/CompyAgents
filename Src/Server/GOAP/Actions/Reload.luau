--!strict

local Action = {
	id = "Reload",
	cost = 1,
	preconditions = {
		hasAmmo = false,
	},
	effects = {
		hasAmmo = true,
	},
}

function Action.Start(agent: { tryReload: () -> boolean }): ()
	agent.tryReload()
end

function Action.Update<Agent>(_agent: Agent, _dt: number): () end

function Action.FinishedCheck<Agent>(agent: Agent & { rifleAmmo: number }): boolean
	return agent.rifleAmmo > 0
end

function Action.End<Agent>(_agent: Agent): () end

return Action
