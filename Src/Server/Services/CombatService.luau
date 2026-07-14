--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local CompyServerScripts = ServerScriptService.CompyAgent
local CompySharedScripts = ReplicatedStorage.CompyAgent

local RifleData = require(CompyServerScripts.Data.RifleData)
local AgentService = require(CompyServerScripts.World.AgentService)
local _DefaultConfig = require(CompySharedScripts.Config)

local CombatService = {}
CombatService.__index = CombatService

type CombatServiceData = {
	config: typeof(_DefaultConfig),
	agentService: AgentService.AgentService,
	pendingDamage: { [number]: number },
	lastShotAt: { [number]: number },
	recordTracer: (number, Vector3, Vector3) -> (),
}

export type CombatService = typeof(setmetatable({} :: CombatServiceData, CombatService))

local function getShotOrigin(character: Model): Vector3
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position
	end
	return character:GetPivot().Position
end

function CombatService.CheckDamage(self: CombatService, agentId: number): number
	local damage = self.pendingDamage[agentId] or 0
	self.pendingDamage[agentId] = nil
	return damage
end

function CombatService.TryShoot(
	self: CombatService,
	shooterId: number,
	character: Model,
	targetPosition: Vector3,
	rifleId: number
): boolean
	local rifle = RifleData[rifleId]
	if not rifle then
		return false
	end

	local now = os.clock()
	if now - (self.lastShotAt[shooterId] or -math.huge) < rifle.shotCooldown then
		return false
	end

	local origin = getShotOrigin(character)
	local direction = targetPosition - origin
	if direction.Magnitude <= 0.001 or direction.Magnitude > self.config.Combat.Range then
		return false
	end

	self.lastShotAt[shooterId] = now
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local result = Workspace:Raycast(origin, direction, params)
	local shotEnd = if result then result.Position else targetPosition
	self.recordTracer(shooterId, origin, shotEnd)

	if not result then
		return true
	end

	local shooter = self.agentService:GetRecord(shooterId)
	local target = self.agentService:GetRecordFromDescendant(result.Instance)
	if not shooter or not target or target.agent.health <= 0 then
		return true
	end
	if not self.config.Combat.FriendlyFire and shooter.teamId == target.teamId then
		return true
	end

	self.pendingDamage[target.id] = (self.pendingDamage[target.id] or 0) + rifle.shotDamage
	return true
end

function CombatService.Clear(self: CombatService): ()
	table.clear(self.pendingDamage)
	table.clear(self.lastShotAt)
end

function CombatService.new(
	config: typeof(_DefaultConfig),
	agentService: AgentService.AgentService,
	recordTracer: (number, Vector3, Vector3) -> ()
): CombatService
	return setmetatable({
		config = config,
		agentService = agentService,
		pendingDamage = {},
		lastShotAt = {},
		recordTracer = recordTracer,
	}, CombatService)
end

return CombatService
