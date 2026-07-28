--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local CompyServerScripts = ServerScriptService.CompyAgent
local CompySharedScripts = ReplicatedStorage.CompyAgent

local EnvironmentService = require(CompyServerScripts.World.EnvironmentService)
local Team = require(CompySharedScripts.Team)

local VisionSensor = {}
VisionSensor.__index = VisionSensor

local DIRECTION_EPSILON = 0.001
local MAX_DIRECTION_NOISE_RADIANS = math.rad(30)

type ModelController = {
	GetModel: (self: ModelController) -> Model,
}

type NearbyAgent = {
	agent: {
		controller: ModelController,
	},
	position: Vector3,
}

type AgentServiceDependency = {
	GetNearbyEnemyAgents: (self: AgentServiceDependency, queryingTeamId: Team.Id, origin: Vector3, radius: number, excludeAgentId: number?) -> { NearbyAgent },
	GetNearbyAgentHeads: (self: AgentServiceDependency, queryingTeamId: Team.Id, origin: Vector3, radius: number, excludeAgentId: number?) -> { BasePart },
}

type Owner = {
	teamId: Team.Id,
	noisyEnemyDirection: Vector3,
	noisyObjectiveDirection: Vector3,
	sightedEnemyLocs: { BasePart },
	sightedObjectiveLocs: { Vector3 },
	sightedCrouchCoverLocs: { Vector3 },
	sightedProneCoverLocs: { Vector3 },
}

type VisionSensorData = {
	agentService: AgentServiceDependency?,
	environmentService: EnvironmentService.EnvironmentService?,
	distance: number,
	id: number,
	character: Model?,
	owner: Owner,
	random: Random,
	raycastParams: RaycastParams?,
}

export type VisionSensor = typeof(setmetatable({} :: VisionSensorData, VisionSensor))

export type Dependencies = {
	agentService: unknown,
	environmentService: EnvironmentService.EnvironmentService,
}

local function getCharacterPosition(character: Model): Vector3
	return character:GetPivot().Position
end

local function getSightOrigin(character: Model): Vector3
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		return rootPart.Position
	end

	return getCharacterPosition(character)
end

local function getNoisyDirection(self: VisionSensor, origin: Vector3, locations: { Vector3 }): Vector3
	if #locations == 0 then
		return Vector3.zero
	end

	local centroid = Vector3.zero
	for _, location in ipairs(locations) do
		centroid += location
	end
	centroid /= #locations

	local offset = centroid - origin
	local horizontalOffset = Vector3.new(offset.X, 0, offset.Z)
	if horizontalOffset.Magnitude <= DIRECTION_EPSILON then
		return Vector3.zero
	end

	local direction = horizontalOffset.Unit
	local angle = self.random:NextNumber(-MAX_DIRECTION_NOISE_RADIANS, MAX_DIRECTION_NOISE_RADIANS)
	local cosine = math.cos(angle)
	local sine = math.sin(angle)
	return Vector3.new(direction.X * cosine - direction.Z * sine, 0, direction.X * sine + direction.Z * cosine)
end

local function getServices(self: VisionSensor): (AgentServiceDependency, EnvironmentService.EnvironmentService)
	local agentService = self.agentService
	local environmentService = self.environmentService
	assert(agentService, "VisionSensor requires AgentService")
	assert(environmentService, "VisionSensor requires EnvironmentService")
	return agentService, environmentService
end

local function getCharacter(self: VisionSensor): Model
	local character = self.character
	assert(character, "VisionSensor requires a character")
	assert(character.Parent, "VisionSensor requires a live character")
	return character
end

function VisionSensor.Awake(self: VisionSensor): ()
	getCharacter(self)
	getServices(self)
end

function VisionSensor.getNoisyEnemyDirection(self: VisionSensor, position: Vector3): Vector3
	local agentService = assert(self.agentService, "VisionSensor requires AgentService")
	local nearbyEnemies = agentService:GetNearbyEnemyAgents(self.owner.teamId, position, self.distance, self.id)

	local locations: { Vector3 } = {}
	for _, nearbyEnemy in ipairs(nearbyEnemies) do
		table.insert(locations, nearbyEnemy.position)
	end
	return getNoisyDirection(self, position, locations)
end

function VisionSensor.getNoisyObjectiveDirection(self: VisionSensor, position: Vector3): Vector3
	local environmentService = assert(self.environmentService, "VisionSensor requires EnvironmentService")
	local objectives = environmentService:QueryObjectivesByDistance(position, self.distance, {
		teamId = self.owner.teamId,
	})
	local locations: { Vector3 } = {}
	for _, objective in ipairs(objectives) do
		table.insert(locations, objective.position)
	end
	return getNoisyDirection(self, position, locations)
end

function VisionSensor.enemyWithinView(self: VisionSensor, position: Vector3, enemyHead: BasePart): boolean
	local raycastParams = assert(self.raycastParams, "VisionSensor requires RaycastParams")

	local enemyCharacter = enemyHead.Parent
	local direction = enemyHead.Position - position
	local distance = direction.Magnitude
	if distance > self.distance then
		return false
	end
	local raycastResult = if distance <= DIRECTION_EPSILON then nil else Workspace:Raycast(position, direction, raycastParams)
	return raycastResult == nil or (enemyCharacter ~= nil and raycastResult.Instance:IsDescendantOf(enemyCharacter))
end

function VisionSensor.getSightedEnemyLocations(self: VisionSensor, sightOrigin: Vector3): { BasePart }
	local agentService = assert(self.agentService, "VisionSensor requires AgentService")
	local nearbyEnemyHeads = agentService:GetNearbyAgentHeads(self.owner.teamId, sightOrigin, self.distance, self.id)
	local sightedEnemyHeads: { BasePart } = {}

	for _, enemyHead in ipairs(nearbyEnemyHeads) do
		if self:enemyWithinView(sightOrigin, enemyHead) then
			table.insert(sightedEnemyHeads, enemyHead)
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.character
		if character then
			local head = character:FindFirstChild("Head")
			if head and self:enemyWithinView(sightOrigin, head) then
				table.insert(sightedEnemyHeads, head)
			end
		end
	end

	return sightedEnemyHeads
end

function VisionSensor.getSightedObjectiveLocations(self: VisionSensor, position: Vector3): { Vector3 }
	local environmentService = assert(self.environmentService, "VisionSensor requires EnvironmentService")
	local objectives = environmentService:QueryObjectivesByDistance(position, self.distance, {
		teamId = self.owner.teamId,
	})
	local locations: { Vector3 } = {}
	for _, objective in ipairs(objectives) do
		table.insert(locations, objective.position)
	end
	return locations
end

local function getSightedCoverLocations(self: VisionSensor, position: Vector3, posture: EnvironmentService.CoverPosture): { Vector3 }
	local environmentService = assert(self.environmentService, "VisionSensor requires EnvironmentService")
	local coverPoints = environmentService:QueryCoverPointsByDistance(position, self.distance, {
		teamId = self.owner.teamId,
		posture = posture,
	})
	local locations: { Vector3 } = {}
	for _, coverPoint in ipairs(coverPoints) do
		table.insert(locations, coverPoint.position)
	end
	return locations
end

function VisionSensor.getSightedCrouchCoverLocations(self: VisionSensor, position: Vector3): { Vector3 }
	return getSightedCoverLocations(self, position, "Crouching")
end

function VisionSensor.getSightedProneCoverLocations(self: VisionSensor, position: Vector3): { Vector3 }
	return getSightedCoverLocations(self, position, "Proning")
end

function VisionSensor.Sense(self: VisionSensor): ()
	local character = getCharacter(self)
	local position = getCharacterPosition(character)
	local sightOrigin = getSightOrigin(character)

	self.owner.noisyEnemyDirection = self:getNoisyEnemyDirection(position)
	self.owner.noisyObjectiveDirection = self:getNoisyObjectiveDirection(position)
	self.owner.sightedEnemyLocs = self:getSightedEnemyLocations(sightOrigin)
	self.owner.sightedObjectiveLocs = self:getSightedObjectiveLocations(position)
	self.owner.sightedCrouchCoverLocs = self:getSightedCrouchCoverLocations(position)
	self.owner.sightedProneCoverLocs = self:getSightedProneCoverLocations(position)
end

function VisionSensor.New(owner: Owner, id: number, character: Model, distance: number, dependencies: Dependencies): VisionSensor
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.IgnoreWater = true

	return setmetatable({
		agentService = dependencies.agentService :: AgentServiceDependency,
		environmentService = dependencies.environmentService,
		distance = distance,
		id = id,
		character = character,
		owner = owner,
		random = Random.new(id),
		raycastParams = raycastParams,
	}, VisionSensor)
end

VisionSensor.Blank = setmetatable({
	agentService = nil,
	environmentService = nil,
	distance = 0,
	id = 0,
	character = nil,
	owner = {
		teamId = "",
		noisyEnemyDirection = Vector3.zero,
		noisyObjectiveDirection = Vector3.zero,
		sightedEnemyLocs = {},
		sightedObjectiveLocs = {},
		sightedCrouchCoverLocs = {},
		sightedProneCoverLocs = {},
	},
	random = Random.new(0),
	raycastParams = nil,
}, VisionSensor)

return VisionSensor
