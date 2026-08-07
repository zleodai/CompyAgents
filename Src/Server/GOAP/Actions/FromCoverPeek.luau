--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local CompySharedScripts = ReplicatedStorage.CompyAgent
local SPHController = require(CompyServerScripts.Integrations.Spearhead.SPHController)
local Types = require(CompyServerScripts.Core.Types)
local AgentConfig = require(CompySharedScripts.Config.AgentConfig)

local function Start(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData): ()
	local pos = controller:GetHeadPart().Position
	local knownEnemies = data.rememberedEnemyLocs
	local avgEnemyDir = Vector3.zero

	for enemy, _ in knownEnemies do
		local enemyDir = (enemy - pos).Unit
		avgEnemyDir += enemyDir
	end

	avgEnemyDir = avgEnemyDir.Unit

	controller:Aim(pos + avgEnemyDir):andThen(function(_): ()
		controller:SetStance("Standing")
	end)
end

local function FinishedCheck(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData): boolean
	return #data.sightedEnemyLocs > 0
end

local function End(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData): ()
	table.clear(actionData)
end

local Action = {}

function Action.new(): Types.Action
	return {
		id = "FromCoverPeek",
		cost = 0.25,
		preconditions = {
			brave = true,
			knowsEnemyPos = true,
			inCover = true,
			coverInvalid = false,
		},
		effects = {
			hasEnemyPos = true,
		},
		actionData = {},
		Start = Start,
		Update = nil,
		FinishedCheck = FinishedCheck,
		End = End,
	}
end

return Action
