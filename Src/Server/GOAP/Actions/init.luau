--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local FindEnemyLocation = require(CompyServerScripts.GOAP.Actions.FindEnemyLocation)
local EngageEnemy = require(CompyServerScripts.GOAP.Actions.EngageEnemy)
local Reload = require(CompyServerScripts.GOAP.Actions.Reload)
local FindObjective = require(CompyServerScripts.GOAP.Actions.FindObjective)
local CaptureObjective = require(CompyServerScripts.GOAP.Actions.CaptureObjective)
local TakeCrouchCover = require(CompyServerScripts.GOAP.Actions.TakeCrouchCover)
local TakeProneCover = require(CompyServerScripts.GOAP.Actions.TakeProneCover)
local StandFromCrouchCover = require(CompyServerScripts.GOAP.Actions.StandFromCrouchCover)
local CrouchFromProneCover = require(CompyServerScripts.GOAP.Actions.CrouchFromProneCover)

local Actions = {}

function Actions.New(): { [string]: Types.Action }
	return {
		["FindEnemyLocation"] = FindEnemyLocation.new(),
		["EngageEnemy"] = EngageEnemy.new(),
		["Reload"] = Reload.new(),
		-- ["FindObjective"] = FindObjective.new(),
		-- ["CaptureObjective"] = CaptureObjective.new(),
		-- ["TakeCrouchCover"] = TakeCrouchCover.new(),
		-- ["TakeProneCover"] = TakeProneCover.new(),
		-- ["StandFromCrouchCover"] = StandFromCrouchCover.new(),
		-- ["CrouchFromProneCover"] = CrouchFromProneCover.new(),
	}
end

function Actions.ToArray(instances: { [string]: Types.Action }): { Types.Action }
	local ordered: { Types.Action } = {}
	for _, action in pairs(instances) do
		table.insert(ordered, action)
	end
	return ordered
end

return Actions
