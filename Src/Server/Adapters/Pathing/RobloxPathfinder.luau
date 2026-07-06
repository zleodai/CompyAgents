--[=[
	RobloxPathfinder

	Path provider adapter for Roblox PathfindingService. It returns the same
	generic waypoint result shape as GridPathfinder, allowing higher-level systems
	to swap pathing modes through configuration.
]=]

local PathfindingService = game:GetService("PathfindingService")
local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local RobloxPathfinder = {}
RobloxPathfinder.__index = RobloxPathfinder

function RobloxPathfinder:FindPath(
	agent: Types.Agent,
	destination: Vector3,
	_worldQuery: Types.WorldQueryAdapter?,
	_now: number?
): Types.PathResult
	local path = PathfindingService:CreatePath()
	local ok, err = pcall(function(): ()
		path:ComputeAsync(agent.transform.position, destination)
	end)

	if not ok or path.Status ~= Enum.PathStatus.Success then
		return {
			status = "Failed",
			waypoints = {},
			reason = ok and tostring(path.Status) or tostring(err),
		}
	end

	local waypoints = {}
	for _, waypoint in ipairs(path:GetWaypoints()) do
		table.insert(waypoints, waypoint.Position)
	end

	return {
		status = "Success",
		waypoints = waypoints,
	}
end

function RobloxPathfinder.new(config: Types.Config): Types.RobloxPathfinderProvider
	local self = setmetatable({}, RobloxPathfinder)

	self.config = config

	return self
end

return RobloxPathfinder
