--[=[
	NoopPathfinder

	PathProvider placeholder used when a higher-level movement adapter owns route
	execution directly.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local NoopPathfinder = {}
NoopPathfinder.__index = NoopPathfinder

function NoopPathfinder:FindPath(
	_agent: Types.Agent,
	_destination: Vector3,
	_worldQuery: Types.WorldQueryAdapter?,
	_now: number?
): Types.PathResult
	return {
		status = "Failed",
		waypoints = {},
		reason = "Pathing is owned by the active movement driver",
	}
end

function NoopPathfinder.new(_config: Types.Config): Types.PathProvider
	return setmetatable({}, NoopPathfinder)
end

return NoopPathfinder
