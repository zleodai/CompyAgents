--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CompyServerScripts = ServerScriptService.CompyAgent
local CompySharedScripts = ReplicatedStorage.CompyAgent
local Enums = require(CompyServerScripts.Core.Enums)
local SPHController = require(CompyServerScripts.Integrations.Spearhead.SPHController)
local Team = require(CompySharedScripts.Team)

local Types = {}

export type BehaviourState = {
	behaviour: Enums.Behaviour,
	behaviourParams: {
		targetPosition: Vector3?,
		posture: number?,
	}?,
}

export type AgentSharedData = {
	teamId: Team.Id,
	noisyEnemyDirection: Vector3,
	noisyObjectiveDirection: Vector3,
	sightedEnemyLocs: { BasePart },
	sightedObjectiveLocs: { Vector3 },
	sightedCrouchCoverLocs: { Vector3 },
	sightedProneCoverLocs: { Vector3 },
	behaviourState: BehaviourState,
	RequestChangeBehaviour: (request: BehaviourState) -> (),
	RequestReplan: (reason: string) -> (),
	RequestMagazine: () -> boolean,
}

export type Goal = {
	id: string,
	priority: number,
	activation: { [string]: boolean },
	desired: { [string]: boolean },
}

export type Action = {
	id: string,
	cost: number,
	preconditions: { [string]: boolean },
	effects: { [string]: boolean },
	actionData: { [any]: any },
	Start: ((actionData: { [any]: any }, controller: SPHController.SPHController, data: AgentSharedData) -> ())?,
	Update: ((actionData: { [any]: any }, controller: SPHController.SPHController, data: AgentSharedData, dt: number) -> ())?,
	FinishedCheck: (actionData: { [any]: any }, controller: SPHController.SPHController, data: AgentSharedData) -> boolean,
	End: ((actionData: { [any]: any }, controller: SPHController.SPHController, data: AgentSharedData) -> ())?,
}

return Types
