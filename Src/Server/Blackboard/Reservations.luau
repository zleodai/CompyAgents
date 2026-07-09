local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Types = require(CompyServerScripts.Core.Types)

local Reservations = {}

function Reservations.TryReserve(
	blackboard: Types.BlackboardStore,
	resourceId: string,
	ownerId: string,
	now: number,
	duration: number
): boolean
	return blackboard:Reserve(resourceId, ownerId, now, duration)
end

function Reservations.Release(blackboard: Types.BlackboardStore, resourceId: string, ownerId: string): ()
	blackboard:ReleaseReservation(resourceId, ownerId)
end

return Reservations
