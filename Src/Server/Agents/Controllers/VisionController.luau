local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Types = require(CompyServerScripts.Core.Types)

local VisionController = {}
VisionController.__index = VisionController

local function isWithinFieldOfView(state: Types.AgentState, targetPosition: Vector3): boolean
	local toTarget = targetPosition - state.position
	if toTarget.Magnitude <= 0.001 then
		return true
	end

	local facing = state.facing.Magnitude > 0.001 and state.facing.Unit or toTarget.Unit
	return facing:Dot(toTarget.Unit) >= -0.15
end

local function getVisionOrigin(state: Types.AgentState, config: Types.Config): Vector3
	return state.head and state.head.Position or state.position + config.Agent.HeadOffset
end

function VisionController:Sense(now: number): ()
	local visibleEnemies = {}

	for _, enemy in ipairs(self.agentService:GetEnemyStates(self.state.teamId)) do
		local offset = enemy.position - self.state.position
		if offset.Magnitude <= self.config.Combat.Range + 18 and isWithinFieldOfView(self.state, enemy.position) then
			local ignore = {}
			if self.state.model then
				table.insert(ignore, self.state.model)
			end
			if enemy.model then
				table.insert(ignore, enemy.model)
			end

			local raycastOrigin = getVisionOrigin(self.state, self.config)
			local raycastTarget = getVisionOrigin(enemy, self.config)
			local hasLineOfSight, raycastEnd = self.environment:RaycastLineOfSight(raycastOrigin, raycastTarget, ignore)

			self.state.lastRaycastAt = now
			self.state.lastRaycastOrigin = raycastOrigin
			self.state.lastRaycastEnd = raycastEnd

			if hasLineOfSight then
				local contact = {
					agentId = enemy.id,
					position = enemy.position,
					confidence = 1,
					lastSeenAt = now,
				}
				table.insert(visibleEnemies, contact)
				self.memory:RememberEnemy(enemy.id, enemy.position, 1, now)
				self.state.knownEnemies[enemy.id] = contact
				self.blackboardClient:PublishEnemySighting(enemy.id, enemy.position, 1, true, now)
			end
		end
	end

	local hadEnemies = #self.state.visibleEnemies > 0
	self.state.visibleEnemies = visibleEnemies

	if #visibleEnemies > 0 and not hadEnemies then
		self.runtime:PushEvent({
			kind = "EnemySpotted",
			at = now,
		})
	elseif #visibleEnemies == 0 and hadEnemies then
		self.runtime:PushEvent({
			kind = "EnemyLost",
			at = now,
		})
	end
end

function VisionController:Tick(now: number): ()
	if now < self.nextSenseAt then
		return
	end

	self.nextSenseAt = now + self.config.Agent.VisionInterval
	self:Sense(now)
end

function VisionController.new(runtime: Types.AgentRuntime): Types.VisionController
	local self = setmetatable({}, VisionController)
	self.runtime = runtime
	self.state = runtime.state
	self.config = runtime.config
	self.environment = runtime.environment
	self.agentService = runtime.agentService
	self.memory = runtime.memory
	self.blackboardClient = runtime.blackboardClient
	self.nextSenseAt = 0
	return self
end

return VisionController
