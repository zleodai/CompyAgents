--[=[
	CombatSystem

	Resolves abstract combat requests on a fixed cadence. It reads AgentCombat
	data, applies damage/ammo effects, and records completion without inspecting
	or advancing GOAP actions.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local AgentController = require(CompyServerScripts.Agents.AgentController)

local CombatSystem = {}
CombatSystem.__index = CombatSystem

local function isTargetInRange(config: Types.Config, agent: Types.Agent, target: Types.Agent): boolean
	return (target.transform.position - agent.transform.position).Magnitude <= config.Combat.Range
end

local function isFacingTarget(config: Types.Config, agent: Types.Agent, target: Types.Agent): boolean
	local toTarget = target.transform.position - agent.transform.position
	if toTarget.Magnitude <= 0.001 then
		return true
	end

	local facing = agent.transform.facing
	if facing.Magnitude <= 0.001 then
		return false
	end

	return facing.Unit:Dot(toTarget.Unit) >= config.Combat.RequiredAimDot
end

function CombatSystem.Step(self: Types.CombatSystem, dt: number, now: number): ()
	self.accumulator = self.accumulator + dt
	if self.accumulator < self.config.Cadence.CombatInterval then
		return
	end
	self.accumulator = 0

	for _, agent in ipairs(self.agentStore:GetAll()) do
		local combat = agent.combat
		local targetId = combat.targetId
		if agent.stats.alive and combat.shouldFire and targetId and agent.stats.ammo > 0 then
			local target = self.agentStore:Get(targetId)

			if
				target
				and target.stats.alive
				and isTargetInRange(self.config, agent, target)
				and isFacingTarget(self.config, agent, target)
				and self.worldQuery:HasLineOfSight(agent.transform.position, target.transform.position)
			then
				agent.stats.ammo = agent.stats.ammo - 1
				target.stats.health = math.max(0, target.stats.health - self.config.Combat.DamagePerTick)
				combat.lastShotAt = now
				combat.lastShotOrigin = agent.transform.position
				combat.lastShotTarget = target.transform.position
				combat.shotCompleted = true
				combat.shouldFire = false

				if target.stats.health <= 0 then
					local targetBlackboard = self.blackboards[target.teamId]
					if targetBlackboard then
						local targetController = AgentController.new(target, {
							config = self.config,
							agentStore = self.agentStore,
							blackboard = targetBlackboard,
							worldQuery = self.worldQuery,
						})
						targetController:Kill()
					else
						target.stats.alive = false
					end
				end
			end
		end
	end
end

function CombatSystem.new(deps: Types.SystemDependencies): Types.CombatSystem
	local self: Types.CombatSystem = {
		config = deps.config,
		agentStore = deps.agentStore,
		blackboards = deps.blackboards,
		worldQuery = deps.adapters.worldQuery,
		accumulator = 0,
		Step = CombatSystem.Step,
	}
	setmetatable(self, CombatSystem)

	return self
end

return CombatSystem
