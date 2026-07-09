local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Types = require(CompyServerScripts.Core.Types)

local CombatController = {}
CombatController.__index = CombatController

local function isFacingTarget(
	config: Types.Config,
	agentState: Types.AgentState,
	targetState: Types.AgentState
): boolean
	local toTarget = targetState.position - agentState.position
	if toTarget.Magnitude <= 0.001 then
		return true
	end

	local facing = agentState.facing
	if facing.Magnitude <= 0.001 then
		return false
	end

	return facing.Unit:Dot(toTarget.Unit) >= config.Combat.RequiredAimDot
end

local function getCombatPoint(state: Types.AgentState, config: Types.Config): Vector3
	return state.head and state.head.Position or state.position + config.Agent.HeadOffset
end

function CombatController:ShootAtTarget(targetId: string): ()
	if self.state.targetId ~= targetId then
		self.state.shotCompleted = false
	end
	self.state.targetId = targetId
end

function CombatController:StopShooting(): ()
	self.state.targetId = nil
	self.state.shotCompleted = false
end

function CombatController:Reload(): ()
	self.state.toReload = true
end

function CombatController:Tick(now: number): ()
	if self.state.toReload then
		self.state.toReload = false
		self.state.reloading = true
		self.state.reloadEndTime = now + self.config.Combat.ReloadTime
		return
	end

	if self.state.reloading then
		if now > self.state.reloadEndTime then
			self.state.reloading = false
			self.state.ammo = self.config.Agent.MaxAmmo
		end

		return
	end

	local targetId = self.state.targetId
	if not targetId or self.state.ammo <= 0 or now - self.state.lastShotAt < self.config.Combat.ShotCooldown then
		return
	end

	local targetRuntime = self.agentService:GetRuntime(targetId)
	if not targetRuntime or not targetRuntime.state.alive then
		self.runtime:PushEvent({
			kind = "TargetInvalid",
			targetId = targetId,
		})
		return
	end

	local target = targetRuntime.state
	local distance = (target.position - self.state.position).Magnitude
	if distance > self.config.Combat.Range or not isFacingTarget(self.config, self.state, target) then
		return
	end

	local ignore = {}
	if self.state.model then
		table.insert(ignore, self.state.model)
	end
	if target.model then
		table.insert(ignore, target.model)
	end

	local shotOrigin = getCombatPoint(self.state, self.config)
	local shotTarget = getCombatPoint(target, self.config)
	local hasLineOfSight, raycastEnd = self.environment:RaycastLineOfSight(shotOrigin, shotTarget, ignore)

	self.state.lastRaycastAt = now
	self.state.lastRaycastOrigin = shotOrigin
	self.state.lastRaycastEnd = raycastEnd

	if not hasLineOfSight then
		return
	end

	self.state.ammo -= 1
	self.state.lastShotAt = now
	self.state.shotCompleted = true
	self.state.lastShotOrigin = shotOrigin
	self.state.lastShotTarget = shotTarget

	targetRuntime:TakeDamage(self.config.Combat.Damage, self.state.id)
end

function CombatController.new(runtime: Types.AgentRuntime): Types.CombatController
	local self = setmetatable({}, CombatController)
	self.runtime = runtime
	self.state = runtime.state
	self.config = runtime.config
	self.environment = runtime.environment
	self.agentService = runtime.agentService
	return self
end

return CombatController
