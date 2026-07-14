--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Goals: {
	{
		id: string,
		priority: number,
		activation: { [string]: boolean },
		desired: { [string]: boolean },
	}
} = {
	require(CompyServerScripts.GOAP.Goals.Survive),
	require(CompyServerScripts.GOAP.Goals.AttackEnemy),
	require(CompyServerScripts.GOAP.Goals.CaptureObjective),
}

return Goals
