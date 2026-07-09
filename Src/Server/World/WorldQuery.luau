local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Types = require(CompyServerScripts.Core.Types)

local WorldQuery = {}

function WorldQuery.GetRetreatPosition(agentState: Types.AgentState, config: Types.Config): Vector3
	local teamConfig = config.Teams[agentState.teamId]
	local retreatDirection = teamConfig and -teamConfig.Forward or -agentState.facing
	return agentState.position + retreatDirection.Unit * 18
end

function WorldQuery.GetAdvancePosition(agentState: Types.AgentState, blackboard: Types.BlackboardStore): Vector3?
	local sighting = blackboard:GetBestEnemySighting()
	if sighting then
		local direction = sighting.position - agentState.position
		if direction.Magnitude > 8 then
			return agentState.position + direction.Unit * math.min(direction.Magnitude - 6, 18)
		end
		return sighting.position
	end
	return nil
end

return WorldQuery
