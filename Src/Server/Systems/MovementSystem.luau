--[=[
	MovementSystem

	Advances AgentMovement requests every frame using the active movement
	adapter. It reacts only to movement data; GOAP action completion is checked
	later by PlanExecutor through AgentController.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local MovementSystem = {}
MovementSystem.__index = MovementSystem

function MovementSystem.Step(self: Types.MovementSystem, dt: number, now: number): ()
	for _, agent in ipairs(self.agentStore:GetAll()) do
		if agent.stats.alive then
			local movement = agent.movement

			if movement.destination and not movement.path and not movement.needsPath and not movement.pathQueued then
				movement.needsPath = true
			end

			local currentPath = movement.path
			if
				movement.destination
				and currentPath
				and currentPath.status == "Failed"
				and not movement.needsPath
				and not movement.pathQueued
				and movement.nextPathAt <= now
			then
				movement.path = nil
				movement.needsPath = true
			end

			local status = self.movementDriver:Step(agent, dt)
			if status == "Reached" then
				movement.destination = nil
				movement.path = nil
				movement.pathIndex = 1
				movement.needsPath = false
				movement.pathQueued = false
				movement.mode = "Idle"
				movement.arrived = true
			end
		end
	end
end

function MovementSystem.new(deps: Types.SystemDependencies): Types.MovementSystem
	local self: Types.MovementSystem = {
		agentStore = deps.agentStore,
		movementDriver = deps.adapters.movementDriver,
		Step = MovementSystem.Step,
	}
	setmetatable(self, MovementSystem)

	return self
end

return MovementSystem
