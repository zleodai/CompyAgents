--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local SPHController = require(CompyServerScripts.Integrations.Spearhead.SPHController)
local Types = require(CompyServerScripts.Core.Types)

local function Start(actionData: { [any]: any }, controller: SPHController.SPHController, _: Types.AgentSharedData): ()
	task.defer(function()
		controller
			:Reload()
			:andThen(function(success: boolean): ()
				if success then
					actionData.reloadCompleted = true
				end
			end)
			:catch(function(reason): ()
				warn("[ ReloadAction ] Reload Failed:", reason)
			end)
	end)
end

local function FinishedCheck(actionData: { [any]: any }, _: SPHController.SPHController, _: Types.AgentSharedData): boolean
	return actionData.reloadCompleted
end

local function End(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData): ()
	table.remove(actionData)
end

local Action = {}

function Action.new(): Types.Action
	return {
		id = "Reload",
		cost = 1,
		preconditions = {
			hasAmmo = false,
		},
		effects = {
			hasAmmo = true,
		},
		actionData = {
			reloadCompleted = false,
		},
		Start = Start,
		Update = nil,
		FinishedCheck = FinishedCheck,
		End = nil,
	}
end

return Action
