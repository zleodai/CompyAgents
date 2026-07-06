--[=[
	GridWorldQuery

	World-query adapter for the grid prototype. It owns grid bounds and action
	destination resolution while exposing the same methods expected from a future
	3D spatial query implementation.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local GridWorldQuery = {}
GridWorldQuery.__index = GridWorldQuery

function GridWorldQuery:ClampToWorld(position: Vector3): Vector3
	local halfWidth = (self.config.Grid.Width * self.config.Grid.CellSize) / 2
	local halfHeight = (self.config.Grid.Height * self.config.Grid.CellSize) / 2

	return Vector3.new(
		math.clamp(position.X, -halfWidth, halfWidth),
		position.Y,
		math.clamp(position.Z, -halfHeight, halfHeight)
	)
end

function GridWorldQuery:HasLineOfSight(_fromPosition: Vector3, _toPosition: Vector3): boolean
	return true
end

function GridWorldQuery:ResolveActionDestination(
	agent: Types.Agent,
	actionId: Types.ActionId,
	blackboard: Types.BlackboardStore
): Vector3
	local teamConfig = self.config.Teams[agent.teamId]
	local forward = teamConfig.Forward

	if actionId == "TakeCover" then
		return self:ClampToWorld(agent.transform.position - forward * self.config.Grid.CellSize)
	end

	if actionId == "Retreat" then
		return self:ClampToWorld(agent.transform.position - forward * self.config.Grid.CellSize * 2)
	end

	local sighting = blackboard:GetBestEnemySighting()
	if sighting then
		if actionId == "AdvanceToEnemy" then
			return self:ClampToWorld(sighting.position - forward * self.config.Grid.CellSize * 2)
		end

		if actionId == "SearchLastKnown" then
			return self:ClampToWorld(sighting.position)
		end
	end

	return self:ClampToWorld(agent.transform.position + forward * self.config.Grid.CellSize)
end

function GridWorldQuery.new(config: Types.Config): Types.GridWorldQueryAdapter
	local self = setmetatable({}, GridWorldQuery)

	self.config = config

	return self
end

return GridWorldQuery
