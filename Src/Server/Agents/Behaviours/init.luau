--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Enums = require(CompyServerScripts.Core.Enums)
local EngagingBehaviour = require(CompyServerScripts.Agents.Behaviours.EngagingBehaviour)
local TakeCoverBehaviour = require(CompyServerScripts.Agents.Behaviours.TakeCoverBehaviour)
local CaptureObjectiveBehaviour = require(CompyServerScripts.Agents.Behaviours.CaptureObjectiveBehaviour)

local ByBehaviour: {
	[number]: typeof(EngagingBehaviour) | typeof(TakeCoverBehaviour) | typeof(CaptureObjectiveBehaviour),
} = {
	[Enums.Behaviour.EngagingEnemy] = EngagingBehaviour,
	[Enums.Behaviour.InCover] = TakeCoverBehaviour,
	[Enums.Behaviour.CapturingObjective] = CaptureObjectiveBehaviour,
}

return {
	EngagingBehaviour = EngagingBehaviour,
	TakeCoverBehaviour = TakeCoverBehaviour,
	CaptureObjectiveBehaviour = CaptureObjectiveBehaviour,
	ByBehaviour = ByBehaviour,
}
