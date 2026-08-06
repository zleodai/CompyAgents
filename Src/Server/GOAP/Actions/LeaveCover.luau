--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local SPHController = require(CompyServerScripts.Integrations.Spearhead.SPHController)
local Types = require(CompyServerScripts.Core.Types)
local Util = require(CompyServerScripts.Core.Util)
local EnvironmentService = require(CompyServerScripts.Services.EnvironmentService)

local function Start(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData): ()
	local name = controller:GetModel().Name
	if not data.cover then
		data.RequestReplan(`LeaveCover called when not data.cover is nil, {name}`)
		return
	end

	task.defer(function()
		controller:SetStance("Standing"):andThen(function(_): ()
			if data.cover then
				EnvironmentService:SetCoverTakenStatus(data.cover, name, false)
				data.cover = nil
			end
			actionData.finished = true
		end)
	end)
end

local function FinishedCheck(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData): boolean
	return actionData.finished or false
end

local function End(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData): ()
	table.clear(actionData)
	data.inCover = false
end

local Action = {}

function Action.new(): Types.Action
	return {
		id = "LeaveCover",
		cost = 0.25,
		preconditions = {
			inCover = true,
		},
		effects = {
			inCover = false,
		},
		actionData = {},
		Start = Start,
		Update = nil,
		FinishedCheck = FinishedCheck,
		End = End,
	}
end

return Action
