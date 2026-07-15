--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Goals: {
	[string]: {
		id: string,
		priority: number,
		activation: { [string]: boolean },
		desired: { [string]: boolean },
	},
} =
	{
		["Survive"] = require(CompyServerScripts.GOAP.Goals.Survive),
		["AttackEnemy"] = require(CompyServerScripts.GOAP.Goals.AttackEnemy),
		["CaptureObjective"] = require(CompyServerScripts.GOAP.Goals.CaptureObjective),
	}

return Goals
