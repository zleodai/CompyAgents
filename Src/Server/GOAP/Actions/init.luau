--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local FindEnemyLocation = require(CompyServerScripts.GOAP.Actions.FindEnemyLocation)
local EngageEnemy = require(CompyServerScripts.GOAP.Actions.EngageEnemy)
local Reload = require(CompyServerScripts.GOAP.Actions.Reload)
local FindObjective = require(CompyServerScripts.GOAP.Actions.FindObjective)
local CaptureObjective = require(CompyServerScripts.GOAP.Actions.CaptureObjective)
local TakeCrouchCover = require(CompyServerScripts.GOAP.Actions.TakeCrouchCover)
local TakeProneCover = require(CompyServerScripts.GOAP.Actions.TakeProneCover)
local StandFromCrouchCover = require(CompyServerScripts.GOAP.Actions.StandFromCrouchCover)
local CrouchFromProneCover = require(CompyServerScripts.GOAP.Actions.CrouchFromProneCover)

local Actions: {
	{
		id: string,
		cost: number,
		preconditions: { [string]: boolean },
		effects: { [string]: boolean },
	}
} = {
	FindEnemyLocation,
	EngageEnemy,
	Reload,
	FindObjective,
	CaptureObjective,
	TakeCrouchCover,
	TakeProneCover,
	StandFromCrouchCover,
	CrouchFromProneCover,
}

return Actions
