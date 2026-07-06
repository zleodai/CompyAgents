--[=[
	Reservations

	Convenience helpers for blackboard resource claims. These functions encode
	resource naming conventions for cover slots, routes, and future tactical
	resources.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local Reservations = {}

function Reservations.TryReserveCover(
	blackboard: Types.BlackboardStore,
	coverId: string,
	ownerId: Types.AgentId,
	now: number,
	duration: number?
): boolean
	return blackboard:Reserve("Cover:" .. tostring(coverId), ownerId, now, duration or 2)
end

function Reservations.TryReserveRoute(
	blackboard: Types.BlackboardStore,
	routeId: string,
	ownerId: Types.AgentId,
	now: number,
	duration: number?
): boolean
	return blackboard:Reserve("Route:" .. tostring(routeId), ownerId, now, duration or 3)
end

return Reservations
