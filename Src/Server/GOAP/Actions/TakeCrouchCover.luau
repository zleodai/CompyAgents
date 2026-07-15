--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local SPHController = require(CompyServerScripts.Integrations.Spearhead.SPHController)
local Types = require(CompyServerScripts.Core.Types)

local function Start(controller: SPHController.SPHController, data: Types.AgentActionData): () end

local function Update(controller: SPHController.SPHController, data: Types.AgentActionData, _dt: number): () end

local function FinishedCheck(controller: SPHController.SPHController, data: Types.AgentActionData): boolean
	return false
end

local function End(controller: SPHController.SPHController, data: Types.AgentActionData): () end

local Action = {}

function Action.new(): Types.Action
	return {
		id = "TakeCrouchCover",
		cost = 1,
		preconditions = {
			crouchCoverInRange = true,
		},
		effects = {
			inDanger = false,
			inCrouchCover = true,
			crouched = true,
		},
		Start = Start,
		Update = Update,
		FinishedCheck = FinishedCheck,
		End = End,
	}
end

return Action
