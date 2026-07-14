--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Enums = require(CompyServerScripts.Core.Enums)

local Action = {
	id = "TakeProneCover",
	cost = 1,
	preconditions = {
		proneCoverInRange = true,
	},
	effects = {
		inDanger = false,
		inProneCover = true,
		proned = true,
	},
}

function Action.Start(agent: {
	sightedProneCoverLocs: { Vector3 },
	requestChangeBehaviour: ({
		behaviour: number,
		behaviourParams: { targetPosition: Vector3?, posture: number? }?,
	}) -> (),
}): ()
	local targetPosition = agent.sightedProneCoverLocs[1]
	if not targetPosition then
		return
	end

	agent.requestChangeBehaviour({
		behaviour = Enums.Behaviour.InCover,
		behaviourParams = {
			targetPosition = targetPosition,
			posture = Enums.Posture.Proning,
		},
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
