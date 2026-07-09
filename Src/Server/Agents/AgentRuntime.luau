local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local CompyServerScripts = ServerScriptService.CompyAgent

local AgentController = require(CompyServerScripts.Agents.AgentController)
local AgentMailbox = require(CompyServerScripts.Agents.AgentMailbox)
local AgentMemory = require(CompyServerScripts.Agents.AgentMemory)
local BlackboardClient = require(CompyServerScripts.Agents.Controllers.BlackboardClient)
local CombatController = require(CompyServerScripts.Agents.Controllers.CombatController)
local MovementController = require(CompyServerScripts.Agents.Controllers.MovementController)
local PlannerController = require(CompyServerScripts.Agents.Controllers.PlannerController)
local VisionController = require(CompyServerScripts.Agents.Controllers.VisionController)
local Types = require(CompyServerScripts.Core.Types)

local AgentRuntime = {}
AgentRuntime.__index = AgentRuntime

local nextThinkStep = 0

function AgentRuntime:Start(): ()
	if self.running then
		return
	end

	self.running = true
	RunService.PostSimulation:Connect(function(dt: number)
		self:_runLoop(dt)
	end)
end

function AgentRuntime:Stop(): ()
	self.running = false
	self.movement:Destroy()
end

function AgentRuntime:PushEvent(event: Types.AgentEvent): ()
	self.mailbox:Push(event)
end

function AgentRuntime:RequestReplan(reason: string): ()
	self.planner:RequestReplan(reason)
end

function AgentRuntime:TakeDamage(amount: number, attackerId: string): ()
	if not self.state.alive then
		return
	end

	self.state.health = math.max(0, self.state.health - amount)
	self:PushEvent({
		kind = "DamageTaken",
		amount = amount,
		attackerId = attackerId,
	})

	if self.state.health <= 0 then
		self:Kill()
	end
end

function AgentRuntime:Kill(): ()
	if not self.state.alive then
		return
	end

	self.state.alive = false
	self.state.debugGoal = "Dead"
	self.state.debugAction = "None"
	self.blackboardClient:PublishDeath(os.clock())
	self.movement:Stop()
	self.modelStore:HideModel(self.state.id)
	self.agentService:BroadcastToTeam(self.state.teamId, {
		kind = "TeammateKilled",
		agentId = self.state.id,
		position = self.state.position,
	})
end

function AgentRuntime:_handleEvent(event: Types.AgentEvent, now: number): ()
	if event.kind == "DamageTaken" then
		self:RequestReplan("damage_taken")
	elseif event.kind == "EnemySpotted" or event.kind == "EnemyLost" then
		self:RequestReplan(event.kind)
	elseif event.kind == "MoveFailed" then
		self:RequestReplan(event.reason or "move_failed")
	elseif event.kind == "TargetInvalid" then
		self:RequestReplan("target_invalid")
	elseif event.kind == "TeammateKilled" and event.agentId ~= self.state.id then
		if event.agentId and event.position then
			self.blackboard:RecordTeammateDeath(event.agentId, event.position, now)
		end
	end
end

function AgentRuntime:_drainMailbox(now: number): ()
	for _, event in ipairs(self.mailbox:Drain()) do
		self:_handleEvent(event, now)
	end
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Util = require(ReplicatedStorage.Packages.Util)

function AgentRuntime:TickBehavior(now: number, dt: number): ()
	if not self.state.alive then
		return
	end

	self:_drainMailbox(now)
	self.blackboardClient:PublishPosition(now)
	self.blackboardClient:Cleanup(now)
	self.vision:Tick(now)
	self.planner:Tick(dt, now)
	self.movement:Tick(dt)
	self.combat:Tick(now)

	if self.config.Agent.DebugLog then
		self.state.inDepthDebugUIText = "LOG:\n"
		self.state.inDepthDebugUIText ..= Util.StringifyTable(self.state)
	end
end

function AgentRuntime:_runLoop(dt: number): ()
	local now = os.clock()

	if now > nextThinkStep then
		self:TickBehavior(now, dt)
		nextThinkStep = now + self.config.Agent.ThinkInterval
	end
end

function AgentRuntime.new(deps: Types.AgentRuntimeDeps): Types.AgentRuntime
	local self = setmetatable({}, AgentRuntime)
	self.config = deps.config
	self.state = deps.state
	self.blackboard = deps.blackboard
	self.environment = deps.environment
	self.agentService = deps.agentService
	self.modelStore = deps.modelStore
	self.mailbox = AgentMailbox.new()
	self.memory = AgentMemory.new()
	self.running = false
	self.thread = nil

	self.blackboardClient = BlackboardClient.new(self)
	self.movement = MovementController.new(self)
	self.combat = CombatController.new(self)
	self.controller = AgentController.new(self)
	self.planner = PlannerController.new(self)
	self.controller.planner = self.planner
	self.vision = VisionController.new(self)

	return self
end

return AgentRuntime
