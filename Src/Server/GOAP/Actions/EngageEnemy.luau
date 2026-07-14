--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Enums = require(CompyServerScripts.Core.Enums)

local Action = {
	id = "EngageEnemy",
	cost = 1,
	preconditions = {
		hasEnemyPos = true,
		inCrouchCover = false,
		inProneCover = false,
		hasAmmo = true,
	},
	effects = {
		enemyEngaged = true,
	},
}

function Action.Start(agent: {
	requestChangeBehaviour: ({
		behaviour: number,
		behaviourParams: { targetPosition: Vector3?, posture: number? }?,
	}) -> (),
}): ()
	agent.requestChangeBehaviour({
		behaviour = Enums.Behaviour.EngagingEnemy,
		behaviourParams = nil,
	})
end

function Action.Update<Agent>(_agent: Agent, _dt: number): () end

function Action.FinishedCheck(agent: {
	behaviourState: {
		behaviour: number,
		behaviourParams: { targetPosition: Vector3?, posture: number? }?,
	},
	behaviourRequest: {
		behaviour: number,
		behaviourParams: { targetPosition: Vector3?, posture: number? }?,
	}?,
}): boolean
	return agent.behaviourRequest == nil and agent.behaviourState.behaviour == Enums.Behaviour.None
end

function Action.End(agent: {
	requestChangeBehaviour: ({
		behaviour: number,
		behaviourParams: { targetPosition: Vector3?, posture: number? }?,
	}) -> (),
}): ()
	agent.requestChangeBehaviour({
		behaviour = Enums.Behaviour.None,
		behaviourParams = nil,
	})
end

return Action
