--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Enums = require(CompyServerScripts.Core.Enums)

local Action = {
	id = "CrouchFromProneCover",
	cost = 1,
	preconditions = {
		inProneCover = true,
	},
	effects = {
		inDanger = false,
		inProneCover = false,
		crouched = true,
	},
}

function Action.Start<Agent>(agent: Agent & { posture: number, movement: number }): ()
	agent.posture = Enums.Posture.Crouching
	agent.movement = Enums.Movement.Idle
end

function Action.Update<Agent>(_agent: Agent, _dt: number): () end

function Action.FinishedCheck<Agent>(agent: Agent & { posture: number }): boolean
	return agent.posture == Enums.Posture.Crouching
end

function Action.End<Agent>(_agent: Agent): () end

return Action
