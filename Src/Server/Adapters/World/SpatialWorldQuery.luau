--[=[
	SpatialWorldQuery

	World-query adapter for a future 3D environment. It provides the same
	destination and line-of-sight contract as GridWorldQuery while using Roblox
	spatial APIs.
]=]

local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local SpatialWorldQuery = {}
SpatialWorldQuery.__index = SpatialWorldQuery

function SpatialWorldQuery:ClampToWorld(position: Vector3): Vector3
	return position
end

function SpatialWorldQuery:HasLineOfSight(fromPosition: Vector3, toPosition: Vector3): boolean
	local direction = toPosition - fromPosition
	local result = Workspace:Raycast(fromPosition, direction)
	return result == nil
end

function SpatialWorldQuery:ResolveActionDestination(
	agent: Types.Agent,
	actionId: Types.ActionId,
	blackboard: Types.BlackboardStore
): Vector3
	local teamConfig = self.config.Teams[agent.teamId]
	local forward = teamConfig.Forward

	if actionId == "TakeCover" or actionId == "Retreat" then
		return agent.transform.position - forward * self.config.Grid.CellSize
	end

	local sighting = blackboard:GetBestEnemySighting()
	if sighting then
		return sighting.position
	end

	return agent.transform.position + forward * self.config.Grid.CellSize
end

function SpatialWorldQuery.new(config: Types.Config): Types.SpatialWorldQueryAdapter
	local self = setmetatable({}, SpatialWorldQuery)

	self.config = config

	return self
end

return SpatialWorldQuery
