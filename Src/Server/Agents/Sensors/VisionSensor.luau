--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local CompyServerScripts = ServerScriptService.CompyAgent
local CompySharedScripts = ReplicatedStorage.CompyAgent

local _DefaultAgentConfig = require(CompySharedScripts.Config.AgentConfig)
local EnvironmentService = require(CompyServerScripts.Services.EnvironmentService)
local Team = require(CompySharedScripts.Team)

local VisionSensor = {}
VisionSensor.__index = VisionSensor

local DIRECTION_EPSILON = 0.001
local MAX_DIRECTION_NOISE_RADIANS = math.rad(30)

type Owner = {
	agentConfig: typeof(_DefaultAgentConfig),
	teamId: Team.Id,
	noisyEnemyDirection: Vector3,
	noisyObjectiveDirection: Vector3,
	sightedEnemyLocs: { BasePart },
	sightedObjectiveLocs: { Vector3 },
}

type VisionSensorData = {
	agentService: any?,
	distance: number,
	id: number,
	character: Model?,
	owner: Owner,
	random: Random,
	raycastParams: RaycastParams?,
}

export type VisionSensor = typeof(setmetatable({} :: VisionSensorData, VisionSensor))

local function getNoisyDirection(self: VisionSensor, origin: Vector3, locations: { Vector3 }): Vector3
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
	local noisyImpact = self.owner.agentConfig.FindEnemyLocation.DirectionNoiseImpact
	assert(noisyImpact, "WTF")
	local noisyDirection = (direction + self.random:NextUnitVector() * noisyImpact) / 2
	return noisyDirection.Unit
end

function VisionSensor.getNoisyEnemyDirection(self: VisionSensor, position: Vector3): Vector3
	if not self.agentService then
		return self.random:NextUnitVector()
	end

	local nearbyEnemies = self.agentService:GetNearbyEnemyAgents(self.owner.teamId, position, self.distance, self.id)

	local locations: { Vector3 } = {}
	for _, nearbyEnemy in ipairs(nearbyEnemies) do
		table.insert(locations, nearbyEnemy.position)
	end
	return getNoisyDirection(self, position, locations)
end

function VisionSensor.getNoisyObjectiveDirection(self: VisionSensor, position: Vector3): Vector3
	local objectives = EnvironmentService:QueryObjectivesByDistance(position, self.distance, {
		teamId = self.owner.teamId,
	})
	local locations: { Vector3 } = {}
	for _, objective in ipairs(objectives) do
		table.insert(locations, objective.position)
	end
	return getNoisyDirection(self, position, locations)
end

function VisionSensor.enemyWithinView(self: VisionSensor, position: Vector3, enemyHead: BasePart): boolean
	local enemyCharacter = enemyHead.Parent
	local direction = enemyHead.Position - position
	local distance = direction.Magnitude
	if distance > self.distance then
		return false
	end
	local raycastResult = if distance <= DIRECTION_EPSILON then nil else Workspace:Raycast(position, direction, self.raycastParams)
	return raycastResult == nil or (enemyCharacter ~= nil and raycastResult.Instance:IsDescendantOf(enemyCharacter))
end

function VisionSensor.getSightedEnemyLocations(self: VisionSensor, sightOrigin: Vector3): { BasePart }
	if not self.agentService then
		return {}
	end

	local nearbyEnemyHeads = self.agentService:GetNearbyAgentHeads(self.owner.teamId, sightOrigin, self.distance, self.id)
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
	local objectives = EnvironmentService:QueryObjectivesByDistance(position, self.distance, {
		teamId = self.owner.teamId,
	})
	local locations: { Vector3 } = {}
	for _, objective in ipairs(objectives) do
		table.insert(locations, objective.position)
	end
	return locations
end

function VisionSensor.Sense(self: VisionSensor): ()
	if not self.character then
		print("Sensor error char not found")
		return
	end

	local position = self.character:GetPivot().Position
	local head = self.character:FindFirstChild("Head")

	if not head or not head:IsA("BasePart") then
		print("Sense error, head not found")
		return
	end

	local sightOrigin = head.Position

	self.owner.noisyEnemyDirection = self:getNoisyEnemyDirection(position)
	self.owner.noisyObjectiveDirection = self:getNoisyObjectiveDirection(position)
	self.owner.sightedEnemyLocs = self:getSightedEnemyLocations(sightOrigin)
	self.owner.sightedObjectiveLocs = self:getSightedObjectiveLocations(position)
end

function VisionSensor.New(owner: Owner, id: number, character: Model, distance: number, agentService: any): VisionSensor
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.IgnoreWater = true

	return setmetatable({
		agentService = agentService,
		distance = distance,
		id = id,
		character = character,
		owner = owner,
		random = Random.new(id),
		raycastParams = raycastParams,
	}, VisionSensor)
end

VisionSensor.Blank = setmetatable(
	{
		agentService = nil,
		distance = 0,
		id = 0,
		character = nil,
		owner = {
			teamId = "",
			noisyEnemyDirection = Vector3.zero,
			noisyObjectiveDirection = Vector3.zero,
			sightedEnemyLocs = {},
			sightedObjectiveLocs = {},
		},
		random = Random.new(0),
		raycastParams = nil,
	} :: VisionSensorData,
	VisionSensor
)

return VisionSensor
