--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CompySharedScripts = ReplicatedStorage.CompyAgent
local _DefaultConfig = require(CompySharedScripts.Config)

local EnvironmentService = {}
EnvironmentService.__index = EnvironmentService

local POSITION_EPSILON = 0.001
local STALE_CLEANUP_INTERVAL = 1

export type CoverPosture = "Crouching" | "Proning"

export type SpawnPointRecord = {
	part: BasePart,
	name: string,
	teamId: string?,
	squadId: string?,
	spawnOrder: number,
	spawnRadius: number,
	cframe: CFrame,
	position: Vector3,
	facing: Vector3,
}

export type CoverPointRecord = {
	part: BasePart,
	name: string,
	coverId: string,
	teamId: string?,
	posture: CoverPosture,
	coverQuality: number,
	cframe: CFrame,
	position: Vector3,
	facing: Vector3,
}

export type ObjectiveRecord = {
	part: BasePart,
	name: string,
	objectiveId: string,
	teamId: string?,
	radius: number,
	cframe: CFrame,
	position: Vector3,
}

export type SpawnPointQueryOptions = {
	teamId: string?,
	squadId: string?,
}

export type CoverPointQueryOptions = {
	teamId: string?,
	posture: CoverPosture?,
}

export type ObjectiveQueryOptions = {
	teamId: string?,
}

type ConnectionsByPart = { [BasePart]: { RBXScriptConnection } }

type EnvironmentServiceData = {
	config: typeof(_DefaultConfig),
	running: boolean,
	cleanupElapsed: number,
	nextRegistrationOrder: number,
	heartbeatConnection: RBXScriptConnection?,
	tagConnections: { RBXScriptConnection },
	registrationOrderByPart: { [BasePart]: number },
	spawnPointsByPart: { [BasePart]: SpawnPointRecord },
	coverPointsByPart: { [BasePart]: CoverPointRecord },
	objectivesByPart: { [BasePart]: ObjectiveRecord },
	spawnPoints: { SpawnPointRecord },
	coverPoints: { CoverPointRecord },
	objectives: { ObjectiveRecord },
	spawnConnectionsByPart: ConnectionsByPart,
	coverConnectionsByPart: ConnectionsByPart,
	objectiveConnectionsByPart: ConnectionsByPart,
}

export type EnvironmentService = typeof(setmetatable({} :: EnvironmentServiceData, EnvironmentService))

type RankedRecord<T> = {
	record: T,
	distanceSquared: number,
	canonicalIndex: number,
}

local function readStringAttribute(instance: Instance, attributeName: string): string?
	local value = instance:GetAttribute(attributeName)
	return if typeof(value) == "string" and value ~= "" then value else nil
end

local function readNumberAttribute(instance: Instance, attributeName: string, defaultValue: number): number
	local value = instance:GetAttribute(attributeName)
	return if typeof(value) == "number" then value else defaultValue
end

local function readSpawnRadius(part: BasePart): number
	local value = part:GetAttribute("SpawnRadius")
	if typeof(value) ~= "number" then
		value = part:GetAttribute("spawnRadius")
	end
	return if typeof(value) == "number" then math.max(0, value) else 0
end

local function readCoverFacing(part: BasePart): Vector3
	local x = part:GetAttribute("FacingX")
	local y = part:GetAttribute("FacingY")
	local z = part:GetAttribute("FacingZ")
	if typeof(x) == "number" and typeof(y) == "number" and typeof(z) == "number" then
		local facing = Vector3.new(x, y, z)
		if facing.Magnitude > POSITION_EPSILON then
			return facing.Unit
		end
	end
	return part.CFrame.LookVector
end

local function readCoverPosture(part: BasePart): CoverPosture
	local posture = part:GetAttribute("Posture")
	if posture == "Proning" then
		return "Proning"
	end
	if posture ~= nil and posture ~= "Crouching" then
		warn(
			("[CompyAgent:EnvironmentService] Invalid Posture on %s; using Crouching"):format(part:GetFullName())
		)
	end
	return "Crouching"
end

local function matchesTeam(recordTeamId: string?, queryTeamId: string?): boolean
	return queryTeamId == nil or recordTeamId == nil or recordTeamId == queryTeamId
end

local function isWorldPart(part: BasePart): boolean
	return part.Parent ~= nil and part:IsDescendantOf(Workspace)
end

local function validateMaxDistance(maxDistance: number): ()
	assert(maxDistance == maxDistance and maxDistance >= 0 and maxDistance < math.huge, "maxDistance must be finite and non-negative")
end

local function disconnectConnections(connections: { RBXScriptConnection }): ()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
end

local function disconnectPartConnections(connectionsByPart: ConnectionsByPart, part: BasePart): ()
	local connections = connectionsByPart[part]
	if connections then
		disconnectConnections(connections)
		connectionsByPart[part] = nil
	end
end

local function clearPartConnections(connectionsByPart: ConnectionsByPart): ()
	for part, connections in pairs(connectionsByPart) do
		disconnectConnections(connections)
		connectionsByPart[part] = nil
	end
end

local function getRegistrationOrder(self: EnvironmentService, part: BasePart): number
	local existing = self.registrationOrderByPart[part]
	if existing then
		return existing
	end
	self.nextRegistrationOrder += 1
	self.registrationOrderByPart[part] = self.nextRegistrationOrder
	return self.nextRegistrationOrder
end

local function partStableLess(self: EnvironmentService, a: BasePart, b: BasePart): boolean
	local aName = a:GetFullName()
	local bName = b:GetFullName()
	if aName ~= bName then
		return aName < bName
	end

	local aPosition = a.Position
	local bPosition = b.Position
	if aPosition.X ~= bPosition.X then
		return aPosition.X < bPosition.X
	end
	if aPosition.Y ~= bPosition.Y then
		return aPosition.Y < bPosition.Y
	end
	if aPosition.Z ~= bPosition.Z then
		return aPosition.Z < bPosition.Z
	end
	return getRegistrationOrder(self, a) < getRegistrationOrder(self, b)
end

local function rebuildSpawnPoints(self: EnvironmentService): ()
	table.clear(self.spawnPoints)
	for _, record in pairs(self.spawnPointsByPart) do
		table.insert(self.spawnPoints, record)
	end
	table.sort(self.spawnPoints, function(a: SpawnPointRecord, b: SpawnPointRecord): boolean
		if a.spawnOrder ~= b.spawnOrder then
			return a.spawnOrder < b.spawnOrder
		end
		return partStableLess(self, a.part, b.part)
	end)
end

local function rebuildCoverPoints(self: EnvironmentService): ()
	table.clear(self.coverPoints)
	for _, record in pairs(self.coverPointsByPart) do
		table.insert(self.coverPoints, record)
	end
	table.sort(self.coverPoints, function(a: CoverPointRecord, b: CoverPointRecord): boolean
		if a.coverId ~= b.coverId then
			return a.coverId < b.coverId
		end
		return partStableLess(self, a.part, b.part)
	end)
end

local function rebuildObjectives(self: EnvironmentService): ()
	table.clear(self.objectives)
	for _, record in pairs(self.objectivesByPart) do
		table.insert(self.objectives, record)
	end
	table.sort(self.objectives, function(a: ObjectiveRecord, b: ObjectiveRecord): boolean
		if a.objectiveId ~= b.objectiveId then
			return a.objectiveId < b.objectiveId
		end
		return partStableLess(self, a.part, b.part)
	end)
end

local function releaseRegistrationOrderIfUnused(self: EnvironmentService, part: BasePart): ()
	if self.spawnPointsByPart[part] or self.coverPointsByPart[part] or self.objectivesByPart[part] then
		return
	end
	self.registrationOrderByPart[part] = nil
end

local function warnForDuplicateCoverId(self: EnvironmentService, record: CoverPointRecord): ()
	for _, existing in ipairs(self.coverPoints) do
		if existing.part ~= record.part and existing.coverId == record.coverId then
			warn(
				("[CompyAgent:EnvironmentService] Duplicate CoverId %q on %s and %s; both records remain registered"):format(
					record.coverId,
					existing.part:GetFullName(),
					record.part:GetFullName()
				)
			)
			return
		end
	end
end

local function warnForDuplicateObjectiveId(self: EnvironmentService, record: ObjectiveRecord): ()
	for _, existing in ipairs(self.objectives) do
		if existing.part ~= record.part and existing.objectiveId == record.objectiveId then
			warn(
				("[CompyAgent:EnvironmentService] Duplicate ObjectiveId %q on %s and %s; both records remain registered"):format(
					record.objectiveId,
					existing.part:GetFullName(),
					record.part:GetFullName()
				)
			)
			return
		end
	end
end

local function rankByDistance<T>(
	records: { T },
	origin: Vector3,
	maxDistance: number,
	matches: (T) -> boolean,
	getPosition: (T) -> Vector3
): { RankedRecord<T> }
	validateMaxDistance(maxDistance)
	local maxDistanceSquared = maxDistance * maxDistance
	local ranked: { RankedRecord<T> } = {}
	for canonicalIndex, record in ipairs(records) do
		if not matches(record) then
			continue
		end
		local offset = getPosition(record) - origin
		local distanceSquared = offset:Dot(offset)
		if distanceSquared <= maxDistanceSquared then
			table.insert(ranked, {
				record = record,
				distanceSquared = distanceSquared,
				canonicalIndex = canonicalIndex,
			})
		end
	end

	table.sort(ranked, function(a: RankedRecord<T>, b: RankedRecord<T>): boolean
		if a.distanceSquared ~= b.distanceSquared then
			return a.distanceSquared < b.distanceSquared
		end
		return a.canonicalIndex < b.canonicalIndex
	end)
	return ranked
end

local function recordsFromRanked<T>(ranked: { RankedRecord<T> }): { T }
	local result: { T } = {}
	for _, item in ipairs(ranked) do
		table.insert(result, item.record)
	end
	return result
end

local function queryByRaycast<T>(
	records: { T },
	origin: Vector3,
	maxDistance: number,
	raycastParams: RaycastParams?,
	matches: (T) -> boolean,
	getPart: (T) -> BasePart,
	getPosition: (T) -> Vector3
): { T }
	local ranked = rankByDistance(records, origin, maxDistance, matches, getPosition)
	local params = raycastParams or RaycastParams.new()
	local result: { T } = {}

	for _, item in ipairs(ranked) do
		local record = item.record
		local targetPart = getPart(record)
		local direction = getPosition(record) - origin
		if direction.Magnitude <= POSITION_EPSILON then
			table.insert(result, record)
			continue
		end

		local raycastResult = Workspace:Raycast(origin, direction, params)
		if raycastResult == nil or raycastResult.Instance == targetPart then
			table.insert(result, record)
		end
	end

	return result
end

local function matchesSpawnOptions(record: SpawnPointRecord, options: SpawnPointQueryOptions?): boolean
	if not options then
		return true
	end
	return matchesTeam(record.teamId, options.teamId) and (options.squadId == nil or record.squadId == options.squadId)
end

local function matchesCoverOptions(record: CoverPointRecord, options: CoverPointQueryOptions?): boolean
	if not options then
		return true
	end
	return matchesTeam(record.teamId, options.teamId) and (options.posture == nil or record.posture == options.posture)
end

local function matchesObjectiveOptions(record: ObjectiveRecord, options: ObjectiveQueryOptions?): boolean
	return options == nil or matchesTeam(record.teamId, options.teamId)
end

local function createSpawnConnections(self: EnvironmentService, part: BasePart): { RBXScriptConnection }
	local connections: { RBXScriptConnection } = {}
	local function refresh(): ()
		if isWorldPart(part) then
			self:RegisterSpawnPoint(part)
		else
			self:UnregisterSpawnPoint(part)
		end
	end

	table.insert(connections, part:GetPropertyChangedSignal("CFrame"):Connect(refresh))
	table.insert(connections, part:GetPropertyChangedSignal("Name"):Connect(refresh))
	for _, attributeName in ipairs({ "TeamId", "SquadId", "SpawnOrder", "SpawnRadius", "spawnRadius" }) do
		table.insert(connections, part:GetAttributeChangedSignal(attributeName):Connect(refresh))
	end
	table.insert(connections, part.AncestryChanged:Connect(refresh))
	table.insert(connections, part.Destroying:Connect(function(): ()
		self:UnregisterSpawnPoint(part)
	end))
	return connections
end

local function createCoverConnections(self: EnvironmentService, part: BasePart): { RBXScriptConnection }
	local connections: { RBXScriptConnection } = {}
	local function refresh(): ()
		if isWorldPart(part) then
			self:RegisterCoverPoint(part)
		else
			self:UnregisterCoverPoint(part)
		end
	end

	table.insert(connections, part:GetPropertyChangedSignal("CFrame"):Connect(refresh))
	table.insert(connections, part:GetPropertyChangedSignal("Name"):Connect(refresh))
	for _, attributeName in ipairs({ "CoverId", "CoverQuality", "TeamId", "Posture", "FacingX", "FacingY", "FacingZ" }) do
		table.insert(connections, part:GetAttributeChangedSignal(attributeName):Connect(refresh))
	end
	table.insert(connections, part.AncestryChanged:Connect(refresh))
	table.insert(connections, part.Destroying:Connect(function(): ()
		self:UnregisterCoverPoint(part)
	end))
	return connections
end

local function createObjectiveConnections(self: EnvironmentService, part: BasePart): { RBXScriptConnection }
	local connections: { RBXScriptConnection } = {}
	local function refresh(): ()
		if isWorldPart(part) then
			self:RegisterObjective(part)
		else
			self:UnregisterObjective(part)
		end
	end

	table.insert(connections, part:GetPropertyChangedSignal("CFrame"):Connect(refresh))
	table.insert(connections, part:GetPropertyChangedSignal("Size"):Connect(refresh))
	table.insert(connections, part:GetPropertyChangedSignal("Name"):Connect(refresh))
	for _, attributeName in ipairs({ "ObjectiveId", "TeamId", "Radius" }) do
		table.insert(connections, part:GetAttributeChangedSignal(attributeName):Connect(refresh))
	end
	table.insert(connections, part.AncestryChanged:Connect(refresh))
	table.insert(connections, part.Destroying:Connect(function(): ()
		self:UnregisterObjective(part)
	end))
	return connections
end

local function clearRegistryRecords(self: EnvironmentService): ()
	clearPartConnections(self.spawnConnectionsByPart)
	clearPartConnections(self.coverConnectionsByPart)
	clearPartConnections(self.objectiveConnectionsByPart)
	table.clear(self.spawnPointsByPart)
	table.clear(self.coverPointsByPart)
	table.clear(self.objectivesByPart)
	table.clear(self.spawnPoints)
	table.clear(self.coverPoints)
	table.clear(self.objectives)
	table.clear(self.registrationOrderByPart)
	self.nextRegistrationOrder = 0
end

local function sortedTaggedInstances(tagName: string): { Instance }
	local instances = CollectionService:GetTagged(tagName)
	table.sort(instances, function(a: Instance, b: Instance): boolean
		local aName = a:GetFullName()
		local bName = b:GetFullName()
		if aName ~= bName then
			return aName < bName
		end
		return a.Name < b.Name
	end)
	return instances
end

local function registerTaggedPart(
	instance: Instance,
	tagName: string,
	register: (BasePart) -> ()
): ()
	if not instance:IsA("BasePart") then
		warn(
			("[CompyAgent:EnvironmentService] Ignoring non-BasePart tagged %s: %s"):format(
				tagName,
				instance:GetFullName()
			)
		)
		return
	end
	register(instance)
end

local function refreshRegistries(self: EnvironmentService): ()
	clearRegistryRecords(self)
	if not self.config.Simulation.UseStudioLevel then
		return
	end

	for _, instance in ipairs(sortedTaggedInstances(self.config.Simulation.SpawnTag)) do
		registerTaggedPart(instance, self.config.Simulation.SpawnTag, function(part: BasePart): ()
			self:RegisterSpawnPoint(part)
		end)
	end
	for _, instance in ipairs(sortedTaggedInstances(self.config.Simulation.CoverTag)) do
		registerTaggedPart(instance, self.config.Simulation.CoverTag, function(part: BasePart): ()
			self:RegisterCoverPoint(part)
		end)
	end
	for _, instance in ipairs(sortedTaggedInstances(self.config.Simulation.ObjectiveTag)) do
		registerTaggedPart(instance, self.config.Simulation.ObjectiveTag, function(part: BasePart): ()
			self:RegisterObjective(part)
		end)
	end
end

local function connectTagListeners(self: EnvironmentService): ()
	if not self.config.Simulation.UseStudioLevel then
		return
	end

	local spawnTag = self.config.Simulation.SpawnTag
	local coverTag = self.config.Simulation.CoverTag
	local objectiveTag = self.config.Simulation.ObjectiveTag

	table.insert(self.tagConnections, CollectionService:GetInstanceAddedSignal(spawnTag):Connect(function(instance: Instance): ()
		registerTaggedPart(instance, spawnTag, function(part: BasePart): ()
			self:RegisterSpawnPoint(part)
		end)
	end))
	table.insert(self.tagConnections, CollectionService:GetInstanceRemovedSignal(spawnTag):Connect(function(instance: Instance): ()
		if instance:IsA("BasePart") then
			self:UnregisterSpawnPoint(instance)
		end
	end))

	table.insert(self.tagConnections, CollectionService:GetInstanceAddedSignal(coverTag):Connect(function(instance: Instance): ()
		registerTaggedPart(instance, coverTag, function(part: BasePart): ()
			self:RegisterCoverPoint(part)
		end)
	end))
	table.insert(self.tagConnections, CollectionService:GetInstanceRemovedSignal(coverTag):Connect(function(instance: Instance): ()
		if instance:IsA("BasePart") then
			self:UnregisterCoverPoint(instance)
		end
	end))

	table.insert(self.tagConnections, CollectionService:GetInstanceAddedSignal(objectiveTag):Connect(function(instance: Instance): ()
		registerTaggedPart(instance, objectiveTag, function(part: BasePart): ()
			self:RegisterObjective(part)
		end)
	end))
	table.insert(self.tagConnections, CollectionService:GetInstanceRemovedSignal(objectiveTag):Connect(function(instance: Instance): ()
		if instance:IsA("BasePart") then
			self:UnregisterObjective(instance)
		end
	end))
end

function EnvironmentService.RegisterSpawnPoint(self: EnvironmentService, part: BasePart): SpawnPointRecord?
	if not isWorldPart(part) then
		warn(("[CompyAgent:EnvironmentService] Cannot register spawn outside Workspace: %s"):format(part:GetFullName()))
		return nil
	end

	getRegistrationOrder(self, part)
	local record: SpawnPointRecord = {
		part = part,
		name = part.Name,
		teamId = readStringAttribute(part, "TeamId"),
		squadId = readStringAttribute(part, "SquadId"),
		spawnOrder = readNumberAttribute(part, "SpawnOrder", 0),
		spawnRadius = readSpawnRadius(part),
		cframe = part.CFrame,
		position = part.Position,
		facing = part.CFrame.LookVector,
	}
	table.freeze(record)

	local isNew = self.spawnPointsByPart[part] == nil
	self.spawnPointsByPart[part] = record
	if isNew then
		self.spawnConnectionsByPart[part] = createSpawnConnections(self, part)
	end
	rebuildSpawnPoints(self)
	return record
end

function EnvironmentService.UnregisterSpawnPoint(self: EnvironmentService, part: BasePart): boolean
	if self.spawnPointsByPart[part] == nil then
		return false
	end
	self.spawnPointsByPart[part] = nil
	disconnectPartConnections(self.spawnConnectionsByPart, part)
	releaseRegistrationOrderIfUnused(self, part)
	rebuildSpawnPoints(self)
	return true
end

function EnvironmentService.RegisterCoverPoint(self: EnvironmentService, part: BasePart): CoverPointRecord?
	if not isWorldPart(part) then
		warn(("[CompyAgent:EnvironmentService] Cannot register cover outside Workspace: %s"):format(part:GetFullName()))
		return nil
	end

	getRegistrationOrder(self, part)
	local record: CoverPointRecord = {
		part = part,
		name = part.Name,
		coverId = readStringAttribute(part, "CoverId") or part.Name,
		teamId = readStringAttribute(part, "TeamId"),
		posture = readCoverPosture(part),
		coverQuality = readNumberAttribute(part, "CoverQuality", 1),
		cframe = part.CFrame,
		position = part.Position,
		facing = readCoverFacing(part),
	}
	table.freeze(record)

	warnForDuplicateCoverId(self, record)
	local isNew = self.coverPointsByPart[part] == nil
	self.coverPointsByPart[part] = record
	if isNew then
		self.coverConnectionsByPart[part] = createCoverConnections(self, part)
	end
	rebuildCoverPoints(self)
	return record
end

function EnvironmentService.UnregisterCoverPoint(self: EnvironmentService, part: BasePart): boolean
	if self.coverPointsByPart[part] == nil then
		return false
	end
	self.coverPointsByPart[part] = nil
	disconnectPartConnections(self.coverConnectionsByPart, part)
	releaseRegistrationOrderIfUnused(self, part)
	rebuildCoverPoints(self)
	return true
end

function EnvironmentService.RegisterObjective(self: EnvironmentService, part: BasePart): ObjectiveRecord?
	if not isWorldPart(part) then
		warn(("[CompyAgent:EnvironmentService] Cannot register objective outside Workspace: %s"):format(part:GetFullName()))
		return nil
	end

	getRegistrationOrder(self, part)
	local record: ObjectiveRecord = {
		part = part,
		name = part.Name,
		objectiveId = readStringAttribute(part, "ObjectiveId") or part.Name,
		teamId = readStringAttribute(part, "TeamId"),
		radius = math.max(0, readNumberAttribute(part, "Radius", math.max(part.Size.X, part.Size.Z) * 0.5)),
		cframe = part.CFrame,
		position = part.Position,
	}
	table.freeze(record)

	warnForDuplicateObjectiveId(self, record)
	local isNew = self.objectivesByPart[part] == nil
	self.objectivesByPart[part] = record
	if isNew then
		self.objectiveConnectionsByPart[part] = createObjectiveConnections(self, part)
	end
	rebuildObjectives(self)
	return record
end

function EnvironmentService.UnregisterObjective(self: EnvironmentService, part: BasePart): boolean
	if self.objectivesByPart[part] == nil then
		return false
	end
	self.objectivesByPart[part] = nil
	disconnectPartConnections(self.objectiveConnectionsByPart, part)
	releaseRegistrationOrderIfUnused(self, part)
	rebuildObjectives(self)
	return true
end

function EnvironmentService.QueryAllSpawnPoints(
	self: EnvironmentService,
	options: SpawnPointQueryOptions?
): { SpawnPointRecord }
	local result: { SpawnPointRecord } = {}
	for _, record in ipairs(self.spawnPoints) do
		if matchesSpawnOptions(record, options) then
			table.insert(result, record)
		end
	end
	return result
end

function EnvironmentService.QuerySpawnPointsByDistance(
	self: EnvironmentService,
	origin: Vector3,
	maxDistance: number,
	options: SpawnPointQueryOptions?
): { SpawnPointRecord }
	return recordsFromRanked(rankByDistance(
		self.spawnPoints,
		origin,
		maxDistance,
		function(record: SpawnPointRecord): boolean
			return matchesSpawnOptions(record, options)
		end,
		function(record: SpawnPointRecord): Vector3
			return record.position
		end
	))
end

function EnvironmentService.QuerySpawnPointsByRaycast(
	self: EnvironmentService,
	origin: Vector3,
	maxDistance: number,
	raycastParams: RaycastParams?,
	options: SpawnPointQueryOptions?
): { SpawnPointRecord }
	return queryByRaycast(
		self.spawnPoints,
		origin,
		maxDistance,
		raycastParams,
		function(record: SpawnPointRecord): boolean
			return matchesSpawnOptions(record, options)
		end,
		function(record: SpawnPointRecord): BasePart
			return record.part
		end,
		function(record: SpawnPointRecord): Vector3
			return record.position
		end
	)
end

function EnvironmentService.QueryAllCoverPoints(
	self: EnvironmentService,
	options: CoverPointQueryOptions?
): { CoverPointRecord }
	local result: { CoverPointRecord } = {}
	for _, record in ipairs(self.coverPoints) do
		if matchesCoverOptions(record, options) then
			table.insert(result, record)
		end
	end
	return result
end

function EnvironmentService.QueryCoverPointsByDistance(
	self: EnvironmentService,
	origin: Vector3,
	maxDistance: number,
	options: CoverPointQueryOptions?
): { CoverPointRecord }
	return recordsFromRanked(rankByDistance(
		self.coverPoints,
		origin,
		maxDistance,
		function(record: CoverPointRecord): boolean
			return matchesCoverOptions(record, options)
		end,
		function(record: CoverPointRecord): Vector3
			return record.position
		end
	))
end

function EnvironmentService.QueryCoverPointsByRaycast(
	self: EnvironmentService,
	origin: Vector3,
	maxDistance: number,
	raycastParams: RaycastParams?,
	options: CoverPointQueryOptions?
): { CoverPointRecord }
	return queryByRaycast(
		self.coverPoints,
		origin,
		maxDistance,
		raycastParams,
		function(record: CoverPointRecord): boolean
			return matchesCoverOptions(record, options)
		end,
		function(record: CoverPointRecord): BasePart
			return record.part
		end,
		function(record: CoverPointRecord): Vector3
			return record.position
		end
	)
end

function EnvironmentService.QueryAllObjectives(
	self: EnvironmentService,
	options: ObjectiveQueryOptions?
): { ObjectiveRecord }
	local result: { ObjectiveRecord } = {}
	for _, record in ipairs(self.objectives) do
		if matchesObjectiveOptions(record, options) then
			table.insert(result, record)
		end
	end
	return result
end

function EnvironmentService.QueryObjectivesByDistance(
	self: EnvironmentService,
	origin: Vector3,
	maxDistance: number,
	options: ObjectiveQueryOptions?
): { ObjectiveRecord }
	return recordsFromRanked(rankByDistance(
		self.objectives,
		origin,
		maxDistance,
		function(record: ObjectiveRecord): boolean
			return matchesObjectiveOptions(record, options)
		end,
		function(record: ObjectiveRecord): Vector3
			return record.position
		end
	))
end

function EnvironmentService.QueryObjectivesByRaycast(
	self: EnvironmentService,
	origin: Vector3,
	maxDistance: number,
	raycastParams: RaycastParams?,
	options: ObjectiveQueryOptions?
): { ObjectiveRecord }
	return queryByRaycast(
		self.objectives,
		origin,
		maxDistance,
		raycastParams,
		function(record: ObjectiveRecord): boolean
			return matchesObjectiveOptions(record, options)
		end,
		function(record: ObjectiveRecord): BasePart
			return record.part
		end,
		function(record: ObjectiveRecord): Vector3
			return record.position
		end
	)
end

function EnvironmentService.Update(self: EnvironmentService, deltaTime: number): ()
	if not self.running then
		return
	end
	self.cleanupElapsed += math.max(0, deltaTime)
	if self.cleanupElapsed < STALE_CLEANUP_INTERVAL then
		return
	end
	self.cleanupElapsed %= STALE_CLEANUP_INTERVAL

	local staleSpawnPoints: { BasePart } = {}
	local staleCoverPoints: { BasePart } = {}
	local staleObjectives: { BasePart } = {}
	for part in pairs(self.spawnPointsByPart) do
		if not isWorldPart(part) then
			table.insert(staleSpawnPoints, part)
		end
	end
	for part in pairs(self.coverPointsByPart) do
		if not isWorldPart(part) then
			table.insert(staleCoverPoints, part)
		end
	end
	for part in pairs(self.objectivesByPart) do
		if not isWorldPart(part) then
			table.insert(staleObjectives, part)
		end
	end
	for _, part in ipairs(staleSpawnPoints) do
		self:UnregisterSpawnPoint(part)
	end
	for _, part in ipairs(staleCoverPoints) do
		self:UnregisterCoverPoint(part)
	end
	for _, part in ipairs(staleObjectives) do
		self:UnregisterObjective(part)
	end
end

function EnvironmentService.Start(self: EnvironmentService): ()
	if self.running then
		return
	end
	self.running = true
	connectTagListeners(self)
	refreshRegistries(self)
	self.heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime: number): ()
		self:Update(deltaTime)
	end)
end

function EnvironmentService.Refresh(self: EnvironmentService): ()
	if not self.running then
		self:Start()
		return
	end
	refreshRegistries(self)
end

function EnvironmentService.End(self: EnvironmentService): ()
	if not self.running then
		clearRegistryRecords(self)
		return
	end
	self.running = false
	self.cleanupElapsed = 0

	local heartbeatConnection = self.heartbeatConnection
	self.heartbeatConnection = nil
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
	end
	disconnectConnections(self.tagConnections)
	clearRegistryRecords(self)
end

function EnvironmentService.new(config: typeof(_DefaultConfig)): EnvironmentService
	return setmetatable({
		config = config,
		running = false,
		cleanupElapsed = 0,
		nextRegistrationOrder = 0,
		heartbeatConnection = nil,
		tagConnections = {},
		registrationOrderByPart = {},
		spawnPointsByPart = {},
		coverPointsByPart = {},
		objectivesByPart = {},
		spawnPoints = {},
		coverPoints = {},
		objectives = {},
		spawnConnectionsByPart = {},
		coverConnectionsByPart = {},
		objectiveConnectionsByPart = {},
	}, EnvironmentService)
end

return EnvironmentService
