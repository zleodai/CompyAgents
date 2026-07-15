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

local ACTION_ORDER = {
	"FindEnemyLocation",
	"EngageEnemy",
	"Reload",
	"FindObjective",
	"CaptureObjective",
	"TakeCrouchCover",
	"TakeProneCover",
	"StandFromCrouchCover",
	"CrouchFromProneCover",
}

local Actions = {
	FindEnemyLocation = FindEnemyLocation,
	EngageEnemy = EngageEnemy,
	Reload = Reload,
	FindObjective = FindObjective,
	CaptureObjective = CaptureObjective,
	TakeCrouchCover = TakeCrouchCover,
	TakeProneCover = TakeProneCover,
	StandFromCrouchCover = StandFromCrouchCover,
	CrouchFromProneCover = CrouchFromProneCover,
}

export type Action = Types.Action
export type ActionSet = { [string]: Types.Action }
export type ActionList = { Types.Action }

function Actions.new(): ActionSet
	return {
		["FindEnemyLocation"] = FindEnemyLocation.new(),
		["EngageEnemy"] = EngageEnemy.new(),
		["Reload"] = Reload.new(),
		["FindObjective"] = FindObjective.new(),
		["CaptureObjective"] = CaptureObjective.new(),
		["TakeCrouchCover"] = TakeCrouchCover.new(),
		["TakeProneCover"] = TakeProneCover.new(),
		["StandFromCrouchCover"] = StandFromCrouchCover.new(),
		["CrouchFromProneCover"] = CrouchFromProneCover.new(),
	}
end

function Actions.ToArray(instances: ActionSet): ActionList
	local ordered: ActionList = {}
	for _, actionName in ipairs(ACTION_ORDER) do
		local action = instances[actionName]
		assert(action, `Types.Action set is missing {actionName}`)
		table.insert(ordered, action)
	end
	return ordered
end

return Actions
