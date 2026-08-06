--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local CompySharedScripts = ReplicatedStorage.CompyAgent
local SPHController = require(CompyServerScripts.Integrations.Spearhead.SPHController)
local Types = require(CompyServerScripts.Core.Types)
local AgentConfig = require(CompySharedScripts.Config.AgentConfig)

local function Start(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData): ()
	controller:SetStance("Crouching")
end

local function FinishedCheck(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData): boolean
	return data.bravery > AgentConfig.MinimumBraveryForBrave
end

local function End(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData): ()
	table.clear(actionData)
end

local Action = {}

function Action.new(): Types.Action
	return {
		id = "FromCoverHide",
		cost = 0.25,
		preconditions = {
			knowsEnemyPos = true,
			inCover = true,
			coverInvalid = false,
		},
		effects = {
			brave = true,
		},
		actionData = {},
		Start = Start,
		Update = nil,
		FinishedCheck = FinishedCheck,
		End = End,
	}
end

return Action
