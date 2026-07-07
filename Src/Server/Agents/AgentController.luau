--[=[
	AgentController

	Per-agent behavior facade passed into GOAP action modules. The controller
	owns behavior requests such as movement, cover, shooting, and lifecycle
	cleanup while systems only react to the resulting AgentState data.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local AgentController = {}
AgentController.__index = AgentController

local function positionsClose(a: Vector3, b: Vector3, tolerance: number): boolean
	return (a - b).Magnitude <= tolerance
end

local function distanceScore(fromPosition: Vector3, toPosition: Vector3): number
	local offset = toPosition - fromPosition
	local distanceSquared = offset:Dot(offset)
	return 1 / math.max(distanceSquared, 0.001)
end

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

function AgentController.RequestPlan(self: Types.AgentController, now: number?, reason: string?): ()
	local agent = self.agentState
	agent.decision.needsPlan = true
	agent.decision.lastPlanReason = reason or "requested"
	agent.decision.nextThinkAt = math.max(agent.decision.nextThinkAt, now or 0)
end

function AgentController.ClearPlan(self: Types.AgentController): ()
	local agent = self.agentState
	agent.decision.currentGoal = nil
	agent.decision.currentPlan = nil
	agent.decision.currentActionIndex = 1
	agent.decision.actionRuntime.actionId = nil
	agent.decision.actionRuntime.started = false
	agent.decision.actionRuntime.startedAt = 0

	agent.movement.destination = nil
	agent.movement.path = nil
	agent.movement.pathIndex = 1
	agent.movement.needsPath = false
	agent.movement.pathQueued = false
	agent.movement.arrived = false
	agent.movement.mode = "Idle"

	agent.combat.targetId = nil
	agent.combat.shouldFire = false
	agent.combat.shotCompleted = false
end

function AgentController.Kill(self: Types.AgentController): ()
	local agent = self.agentState
	agent.stats.alive = false
	self:ClearPlan()
end

function AgentController.MoveTo(self: Types.AgentController, destination: Vector3): ()
	local agent = self.agentState
	local clampedDestination = self.worldQuery:ClampToWorld(destination)

	if positionsClose(agent.transform.position, clampedDestination, self.config.Movement.WaypointTolerance) then
		agent.movement.destination = nil
		agent.movement.path = nil
		agent.movement.pathIndex = 1
		agent.movement.needsPath = false
		agent.movement.pathQueued = false
		agent.movement.arrived = true
		agent.movement.mode = "Idle"
		return
	end

	local currentDestination = agent.movement.destination
	if currentDestination and positionsClose(currentDestination, clampedDestination, 0.01) then
		return
	end

	agent.movement.destination = clampedDestination
	agent.movement.path = nil
	agent.movement.pathIndex = 1
	agent.movement.needsPath = true
	agent.movement.pathQueued = false
	agent.movement.arrived = false
end

function AgentController.MoveForAction(self: Types.AgentController, actionId: Types.ActionId): ()
	local destination = self.worldQuery:ResolveActionDestination(self.agentState, actionId, self.blackboard)
	self:MoveTo(destination)
end

function AgentController.TakeCoverAt(self: Types.AgentController, coverPosition: Vector3): ()
	self:MoveTo(coverPosition)
end

function AgentController.LookAtPosition(self: Types.AgentController, targetPosition: Vector3, dt: number): ()
	local agent = self.agentState
	local desiredDirection = targetPosition - agent.transform.position
	local maxRadians = self.config.Movement.FacingTurnRateRadiansPerSecond * dt
	agent.transform.facing = rotateTowards(agent.transform.facing, desiredDirection, maxRadians)
end

function AgentController.ShootAtTarget(self: Types.AgentController, targetId: Types.AgentId): ()
	local combat = self.agentState.combat

	if combat.targetId ~= targetId then
		combat.shotCompleted = false
	end

	combat.targetId = targetId
	combat.shouldFire = true
end

function AgentController.StopShooting(self: Types.AgentController): ()
	local combat = self.agentState.combat
	combat.targetId = nil
	combat.shouldFire = false
	combat.shotCompleted = false
end

function AgentController.SetInCover(self: Types.AgentController, inCover: boolean): ()
	self.agentState.tactical.inCover = inCover
end

function AgentController.GetBestVisibleEnemy(self: Types.AgentController): Types.PerceptionContact?
	local agentPosition = self.agentState.transform.position
	local bestContact: Types.PerceptionContact? = nil
	local bestScore = -math.huge

	for _, contact in ipairs(self.agentState.perception.visibleEnemies) do
		local target = self.agentStore:Get(contact.agentId)
		if target and target.stats.alive then
			local score = distanceScore(agentPosition, target.transform.position)
			if score > bestScore then
				bestContact = contact
				bestScore = score
			end
		end
	end

	return bestContact
end

function AgentController.GetBestKnownEnemyPosition(self: Types.AgentController): Vector3?
	local visibleEnemy = self:GetBestVisibleEnemy()
	if visibleEnemy then
		return visibleEnemy.position
	end

	local sighting = self.blackboard:GetBestEnemySighting()
	if sighting then
		return sighting.position
	end

	return nil
end

function AgentController.HasReachedDestination(self: Types.AgentController): boolean
	return self.agentState.movement.arrived
end

function AgentController.HasCompletedShot(self: Types.AgentController): boolean
	return self.agentState.combat.shotCompleted
end

function AgentController.GetActionElapsed(self: Types.AgentController, now: number): number
	return now - self.agentState.decision.actionRuntime.startedAt
end

function AgentController.new(agentState: Types.Agent, deps: Types.AgentControllerDependencies): Types.AgentController
	local self: Types.AgentController = {
		agentState = agentState,
		config = deps.config,
		agentStore = deps.agentStore,
		blackboard = deps.blackboard,
		worldQuery = deps.worldQuery,
		RequestPlan = AgentController.RequestPlan,
		ClearPlan = AgentController.ClearPlan,
		Kill = AgentController.Kill,
		MoveTo = AgentController.MoveTo,
		MoveForAction = AgentController.MoveForAction,
		TakeCoverAt = AgentController.TakeCoverAt,
		LookAtPosition = AgentController.LookAtPosition,
		ShootAtTarget = AgentController.ShootAtTarget,
		StopShooting = AgentController.StopShooting,
		SetInCover = AgentController.SetInCover,
		GetBestVisibleEnemy = AgentController.GetBestVisibleEnemy,
		GetBestKnownEnemyPosition = AgentController.GetBestKnownEnemyPosition,
		HasReachedDestination = AgentController.HasReachedDestination,
		HasCompletedShot = AgentController.HasCompletedShot,
		GetActionElapsed = AgentController.GetActionElapsed,
	}
	setmetatable(self, AgentController)

	return self
end

return AgentController
