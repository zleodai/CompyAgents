--[=[
	GridMovement

	Data-only movement driver that advances agents along Vector3 waypoints. Grid
	mode uses this directly, and 3D movement can keep the same SetPath/Step
	contract.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local GridMovement = {}
GridMovement.__index = GridMovement

local function rotateTowards(currentDirection: Vector3, desiredDirection: Vector3, maxRadians: number): Vector3
	if desiredDirection.Magnitude <= 0.001 then
		return currentDirection
	end

	local desiredUnit = desiredDirection.Unit
	local currentUnit = currentDirection.Magnitude > 0.001 and currentDirection.Unit or desiredUnit
	local dot = math.clamp(currentUnit:Dot(desiredUnit), -1, 1)
	local angle = math.acos(dot)

	if angle <= maxRadians or angle <= 0.001 then
		return desiredUnit
	end

	local alpha = math.clamp(maxRadians / angle, 0, 1)
	local blended = currentUnit:Lerp(desiredUnit, alpha)
	if blended.Magnitude <= 0.001 then
		return desiredUnit
	end

	return blended.Unit
end

function GridMovement:SetPath(agent: Types.Agent, pathResult: Types.PathResult): ()
	agent.movement.path = pathResult
	agent.movement.pathIndex = 1
	agent.movement.mode = pathResult.status == "Success" and "Moving" or "Idle"
end

function GridMovement:Step(agent: Types.Agent, dt: number): Types.MovementStatus
	local path = agent.movement.path
	if not path or path.status ~= "Success" or #path.waypoints == 0 then
		return "Idle"
	end

	local index = agent.movement.pathIndex
	local waypoint = path.waypoints[index]
	if not waypoint then
		return "Reached"
	end

	local position = agent.transform.position
	local offset = waypoint - position
	local distance = offset.Magnitude

	if distance <= self.config.Movement.WaypointTolerance then
		agent.movement.pathIndex = agent.movement.pathIndex + 1
		if agent.movement.pathIndex > #path.waypoints then
			agent.movement.mode = "Idle"
			return "Reached"
		end
		return "Moving"
	end

	local stepDistance = math.min(self.config.Movement.Speed * dt, distance)
	agent.transform.position = position + offset.Unit * stepDistance
	if offset.Magnitude > 0.001 then
		local maxRadians = self.config.Movement.FacingTurnRateRadiansPerSecond * dt
		agent.transform.facing = rotateTowards(agent.transform.facing, offset, maxRadians)
	end

	return "Moving"
end

function GridMovement.new(config: Types.Config): Types.GridMovementDriver
	local self = setmetatable({}, GridMovement)

	self.config = config

	return self
end

return GridMovement
