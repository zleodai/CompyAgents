--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local SPHController = require(CompyServerScripts.Integrations.Spearhead.SPHController)

local Types = {}

export type BehaviourState = {
	behaviour: number,
	behaviourParams: {
		targetPosition: Vector3?,
		posture: number?,
	}?,
}

export type AgentActionData = {
	sightedEnemyLocs: { Vector3 },
	sightedObjectiveLocs: { Vector3 },
	sightedCrouchCoverLocs: { Vector3 },
	sightedProneCoverLocs: { Vector3 },
	behaviourState: BehaviourState,
	RequestChangeBehaviour: (request: BehaviourState) -> (),
	RequestReplan: (_reason: string) -> (),
}

export type Action = {
	id: string,
	cost: number,
	preconditions: { [string]: boolean },
	effects: { [string]: boolean },
	Start: (controller: SPHController.SPHController, data: AgentActionData) -> (),
	Update: (controller: SPHController.SPHController, data: AgentActionData, dt: number) -> (),
	FinishedCheck: (controller: SPHController.SPHController, data: AgentActionData) -> boolean,
	End: (controller: SPHController.SPHController, data: AgentActionData) -> (),
}

return Types
