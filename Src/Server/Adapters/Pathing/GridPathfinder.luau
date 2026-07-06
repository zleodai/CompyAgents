--[=[
	GridPathfinder

	Lightweight path provider for the grid prototype. It returns generic Vector3
	waypoints so movement and GOAP code do not depend on grid-cell internals.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local GridPathfinder = {}
GridPathfinder.__index = GridPathfinder

function GridPathfinder:FindPath(
	agent: Types.Agent,
	destination: Vector3,
	worldQuery: Types.WorldQueryAdapter,
	_now: number?
): Types.PathResult
	local start = agent.transform.position
	local snappedDestination = worldQuery:ClampToWorld(destination)

	return {
		status = "Success",
		waypoints = {
			start,
			snappedDestination,
		},
	}
end

function GridPathfinder.new(config: Types.Config): Types.GridPathfinderProvider
	local self = setmetatable({}, GridPathfinder)

	self.config = config

	return self
end

return GridPathfinder
