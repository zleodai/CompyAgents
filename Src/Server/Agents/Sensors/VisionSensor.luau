--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local CompyServerScripts = ServerScriptService.CompyAgent
local CompySharedScripts = ReplicatedStorage.CompyAgent

local Types = require(CompyServerScripts.Core.Types)
local AgentConfig = require(CompySharedScripts.Config.AgentConfig)
local EnvironmentService = require(CompyServerScripts.Services.EnvironmentService)

local VisionSensor = {}
VisionSensor.__index = VisionSensor

local DIRECTION_EPSILON = 0.001

type VisionSensorData = {
	config: typeof(AgentConfig)?,
	agentSharedData: Types.AgentSharedData?,

	agentService: any?,
	id: number,
	character: Model?,
	head: BasePart?,
	debugParts: { [string]: Part? }?,
	random: Random,
	raycastParams: RaycastParams?,
}

export type VisionSensor = typeof(setmetatable({} :: VisionSensorData, VisionSensor))

local function getNoisyDirection(self: VisionSensor, origin: Vector3, locations: { Vector3 }): Vector3
	if not self.config or not self.agentSharedData then
		return Vector3.zero
	end

	if #locations == 0 then
		return self.random:NextUnitVector()
	end

	local centroid = Vector3.zero
	for _, location in ipairs(locations) do
		centroid += location
	end
	centroid /= #locations

	local offset = centroid - origin
	local horizontalOffset = Vector3.new(offset.X, 0, offset.Z)
	if horizontalOffset.Magnitude <= DIRECTION_EPSILON then
		return self.random:NextUnitVector()
	end

	local direction = horizontalOffset.Unit
	local noisyImpact = self.config.FindEnemyLocation.DirectionNoiseImpact
	local noisyDirection = (direction + self.random:NextUnitVector() * noisyImpact) / 2
	return noisyDirection.Unit
end

function VisionSensor.getNoisyEnemyDirection(self: VisionSensor, position: Vector3): Vector3
	if not self.config or not self.agentSharedData then
		return Vector3.zero
	end

	if not self.agentService then
		return self.random:NextUnitVector()
	end

	local nearbyEnemies = self.agentService:GetNearbyEnemyAgents(self.agentSharedData.teamId, position, self.config.VisionDistance, self.id)

	local locations: { Vector3 } = {}
	for _, nearbyEnemy in ipairs(nearbyEnemies) do
		table.insert(locations, nearbyEnemy.position)
	end
	return getNoisyDirection(self, position, locations)
end

function VisionSensor.getNoisyObjectiveDirection(self: VisionSensor, position: Vector3): Vector3
	if not self.config or not self.agentSharedData then
		return Vector3.zero
	end

	local objectives = EnvironmentService:QueryObjectivesByDistance(position, self.config.VisionDistance, {
		teamId = self.agentSharedData.teamId,
	})
	local locations: { Vector3 } = {}
	for _, objective in ipairs(objectives) do
		table.insert(locations, objective.position)
	end
	return getNoisyDirection(self, position, locations)
end

function VisionSensor.enemyWithinView(self: VisionSensor, position: Vector3, enemyHead: BasePart): boolean
	if not self.head or not self.config or not self.agentSharedData then
		return false
	end

	local enemyCharacter = enemyHead.Parent
	local direction = enemyHead.Position - position

	local angDiff = math.deg(direction:Angle(self.head.CFrame.LookVector))
	if angDiff > self.config.VisionAngle then
		return false
	end

	local distance = direction.Magnitude
	if distance > self.config.VisionDistance then
		return false
	end

	local raycastResult = if distance <= DIRECTION_EPSILON then nil else Workspace:Raycast(position, direction, self.raycastParams)
	return raycastResult == nil or (enemyCharacter ~= nil and raycastResult.Instance:IsDescendantOf(enemyCharacter))
end

function VisionSensor.getSightedEnemyLocations(self: VisionSensor, sightOrigin: Vector3): { BasePart }
	if not self.agentService or not self.config or not self.agentSharedData then
		return {}
	end

	local nearbyEnemyHeads = self.agentService:GetNearbyAgentHeads(self.agentSharedData.teamId, sightOrigin, self.config.VisionDistance, self.id)
	local sightedEnemyHeads: { BasePart } = {}

	for _, enemyHead in ipairs(nearbyEnemyHeads) do
		if self:enemyWithinView(sightOrigin, enemyHead) then
			table.insert(sightedEnemyHeads, enemyHead)
		end
	end

	-- FOR IF YOU WANT PLAYER TO BE TARGETED
	-- for _, player in ipairs(Players:GetPlayers()) do
	-- 	local character = player.character
	-- 	if character then
	-- 		local head = character:FindFirstChild("Head")
	-- 		if head and self:enemyWithinView(sightOrigin, head) then
	-- 			table.insert(sightedEnemyHeads, head)
	-- 		end
	-- 	end
	-- end

	return sightedEnemyHeads
end

function VisionSensor.getSightedObjectiveLocations(self: VisionSensor, position: Vector3): { Vector3 }
	if not self.config or not self.agentSharedData then
		return {}
	end

	local objectives = EnvironmentService:QueryObjectivesByDistance(position, self.config.VisionDistance, {
		teamId = self.agentSharedData.teamId,
	})
	local locations: { Vector3 } = {}
	for _, objective in ipairs(objectives) do
		table.insert(locations, objective.position)
	end
	return locations
end

function VisionSensor.Sense(self: VisionSensor): ()
	if not self.character or not self.head or not self.config or not self.agentSharedData then
		return
	end

	local position = self.character:GetPivot().Position
	local sightOrigin = self.head.Position

	self.agentSharedData.noisyEnemyDirection = self:getNoisyEnemyDirection(position)
	self.agentSharedData.noisyObjectiveDirection = self:getNoisyObjectiveDirection(position)
	self.agentSharedData.sightedEnemyLocs = self:getSightedEnemyLocations(sightOrigin)
	self.agentSharedData.sightedObjectiveLocs = self:getSightedObjectiveLocations(position)
end

function VisionSensor.New(agentSharedData: Types.AgentSharedData, config: typeof(AgentConfig), id: number, character: Model, agentService: any): VisionSensor
	local head = character:FindFirstChild("Head") :: Part

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.IgnoreWater = true

	return setmetatable({
		config = config,
		agentSharedData = agentSharedData,

		agentService = agentService,
		id = id,
		character = character,
		head = head,
		debugParts = {} :: { [string]: Part? },
		random = Random.new(id),
		raycastParams = raycastParams,
	}, VisionSensor)
end

VisionSensor.Blank = setmetatable({} :: VisionSensorData, VisionSensor)

return VisionSensor
