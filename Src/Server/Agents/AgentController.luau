local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local WorldQuery = require(CompyServerScripts.World.WorldQuery)
local Types = require(CompyServerScripts.Core.Types)

local AgentController = {}
AgentController.__index = AgentController

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

function AgentController:RequestPlan(reason: string): ()
	self.runtime:RequestReplan(reason)
end

function AgentController:ClearPlan(): ()
	self.planner:ClearPlan()
end

function AgentController:Kill(): ()
	self.runtime:Kill()
end

function AgentController:Reload(): ()
	self.combat:Reload()
end

function AgentController:MoveTo(destination: Vector3): ()
	self.movement:SetDestination(self.environment:ClampDestination(destination))
end

function AgentController:StopMovement(): ()
	self.movement:Stop()
end

function AgentController:MoveForAction(actionId: string): ()
	local destination = nil

	if actionId == "TakeCover" then
		destination = self.environment:GetNearestCover(self.state.position, self.state.teamId)
	elseif actionId == "Retreat" then
		destination = WorldQuery.GetRetreatPosition(self.state, self.config)
	else
		destination = WorldQuery.GetAdvancePosition(self.state, self.blackboard)
	end

	if destination then
		self:MoveTo(destination)
	else
		self:RequestPlan(actionId .. "_missing_destination")
	end
end

function AgentController:LookAtPosition(targetPosition: Vector3, dt: number): ()
	local desiredDirection = targetPosition - self.state.position
	local maxRadians = self.config.Combat.TurnRateRadiansPerSecond * dt
	self.state.facing = rotateTowards(self.state.facing, desiredDirection, maxRadians)
end

function AgentController:ShootAtTarget(targetId: string): ()
	self.combat:ShootAtTarget(targetId)
end

function AgentController:StopShooting(): ()
	self.combat:StopShooting()
end

function AgentController:SetInCover(inCover: boolean): ()
	self.state.inCover = inCover
end

function AgentController:GetBestVisibleEnemy(): Types.PerceptionContact?
	local bestContact = nil
	local bestDistance = math.huge

	for _, contact in ipairs(self.state.visibleEnemies) do
		local distance = (contact.position - self.state.position).Magnitude
		if distance < bestDistance then
			bestDistance = distance
			bestContact = contact
		end
	end

	return bestContact
end

function AgentController:GetBestKnownEnemyPosition(): Vector3?
	local visibleEnemy = self:GetBestVisibleEnemy()
	if visibleEnemy then
		return visibleEnemy.position
	end

	local knownEnemy = self.memory:GetBestKnownEnemy()
	if knownEnemy then
		return knownEnemy.position
	end

	local sighting = self.blackboard:GetBestEnemySighting()
	return sighting and sighting.position or nil
end

function AgentController:HasReachedDestination(): boolean
	return self.state.arrived
end

function AgentController:HasCompletedShot(): boolean
	return self.state.shotCompleted
end

function AgentController:HasCompletedReload(): boolean
	return self.state.reloading
end

function AgentController:GetActionElapsed(now: number): number
	return now - self.state.actionStartedAt
end

function AgentController.new(runtime: Types.AgentRuntime): Types.AgentController
	local self = setmetatable({}, AgentController)
	self.runtime = runtime
	self.state = runtime.state
	self.config = runtime.config
	self.blackboard = runtime.blackboard
	self.environment = runtime.environment
	self.memory = runtime.memory
	self.movement = runtime.movement
	self.combat = runtime.combat
	self.planner = runtime.planner
	return self
end

return AgentController
