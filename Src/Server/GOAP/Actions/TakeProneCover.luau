--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local SPHController = require(CompyServerScripts.Integrations.Spearhead.SPHController)
local Types = require(CompyServerScripts.Core.Types)

local function Start(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData): () end

local function Update(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData, _dt: number): () end

local function FinishedCheck(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData): boolean
	return false
end

local function End(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData): ()
	table.remove(actionData)
end

local Action = {}

function Action.new(): Types.Action
	return {
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
		actionData = {},
		Start = Start,
		Update = Update,
		FinishedCheck = FinishedCheck,
		End = End,
	}
end

return Action
