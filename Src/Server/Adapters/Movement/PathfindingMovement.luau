--[=[
	PathfindingMovement

	3D movement adapter shell. It currently delegates waypoint following to
	GridMovement, preserving the same interface for a later Humanoid or custom
	controller implementation.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local GridMovement = require(CompyServerScripts.Adapters.Movement.GridMovement)

local PathfindingMovement = {}
PathfindingMovement.__index = PathfindingMovement

function PathfindingMovement:SetPath(agent: Types.Agent, pathResult: Types.PathResult): ()
	self.gridDriver:SetPath(agent, pathResult)
end

function PathfindingMovement:Step(agent: Types.Agent, dt: number): Types.MovementStatus
	return self.gridDriver:Step(agent, dt)
end

function PathfindingMovement.new(config: Types.Config): Types.PathfindingMovementDriver
	local self = setmetatable({}, PathfindingMovement)

	self.gridDriver = GridMovement.new(config)

	return self
end

return PathfindingMovement
