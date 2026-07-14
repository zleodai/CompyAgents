--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Enums = require(CompyServerScripts.Core.Enums)

local Action = {
	id = "StandFromCrouchCover",
	cost = 1,
	preconditions = {
		inCrouchCover = true,
	},
	effects = {
		inDanger = false,
		inCrouchCover = false,
		standing = true,
	},
}

function Action.Start<Agent>(agent: Agent & { posture: number, movement: number }): ()
	agent.posture = Enums.Posture.Standing
	agent.movement = Enums.Movement.Idle
end

function Action.Update<Agent>(_agent: Agent, _dt: number): () end

function Action.FinishedCheck<Agent>(agent: Agent & { posture: number }): boolean
	return agent.posture == Enums.Posture.Standing
end

function Action.End<Agent>(_agent: Agent): () end

return Action
