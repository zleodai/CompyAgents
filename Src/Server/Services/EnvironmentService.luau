--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CompySharedScripts = ReplicatedStorage.CompyAgent
local Config = require(CompySharedScripts.Config)

local EnvironmentService = {}
EnvironmentService.__index = EnvironmentService

local POSITION_EPSILON = 0.001
local STALE_CLEANUP_INTERVAL = 1
local NO_ROOM = "None"

export type CoverPosture = "Crouching" | "Proning"

export type SpawnPointRecord = {
	part: BasePart,
	name: string,
	enabled: boolean,
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

export type RoomScript = {
	GetRoom: () -> string,
	GetAgents: () -> { string },
}

export type DoorScript = {
	Open: () -> (),
	Close: () -> (),
	GetRoom: () -> string,
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
type ConnectionsByModel = { [Model]: { RBXScriptConnection } }

type EnvironmentServiceData = {
	config: typeof(Config),
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
	rooms: { [string]: RoomScript },
	doors: { [string]: DoorScript },
	agentRoomsByName: { [string]: string },
	roomScriptsByModel: { [Model]: RoomScript },
	doorScriptsByModel: { [Model]: DoorScript },
	roomNamesByModel: { [Model]: string },
	doorRoomNamesByModel: { [Model]: string },
	roomModelsByName: { [string]: Model },
	doorModelsByName: { [string]: Model },
	spawnConnectionsByPart: ConnectionsByPart,
	coverConnectionsByPart: ConnectionsByPart,
	objectiveConnectionsByPart: ConnectionsByPart,
	roomConnectionsByModel: ConnectionsByModel,
	doorConnectionsByModel: ConnectionsByModel,
	registrationOrderByModel: { [Model]: number },
}

export type EnvironmentService = typeof(setmetatable({} :: EnvironmentServiceData, EnvironmentService))

type RankedRecord<T> = {
	record: T,
	distanceSquared: number,
	canonicalIndex: number,
}

local function readBoolAttribute(instance: Instance, attributeName: string): boolean
	local value = instance:GetAttribute(attributeName)
	return if typeof(value) == "boolean" then value else false
end

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
		warn(("[CompyAgent:EnvironmentService] Invalid Posture on %s; using Crouching"):format(part:GetFullName()))
	end
	return "Crouching"
end

local function matchesTeam(recordTeamId: string?, queryTeamId: string?): boolean
	return queryTeamId == nil or recordTeamId == nil or recordTeamId == queryTeamId
end

local function isWorldPart(part: BasePart): boolean
	return part.Parent ~= nil and part:IsDescendantOf(Workspace)
end

local function isWorldModel(model: Model): boolean
	return model.Parent ~= nil and model:IsDescendantOf(Workspace)
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

local function disconnectModelConnections(connectionsByModel: ConnectionsByModel, model: Model): ()
	local connections = connectionsByModel[model]
	if connections then
		disconnectConnections(connections)
		connectionsByModel[model] = nil
	end
end

local function clearModelConnections(connectionsByModel: ConnectionsByModel): ()
	for model, connections in pairs(connectionsByModel) do
		disconnectConnections(connections)
		connectionsByModel[model] = nil
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

local function getModelRegistrationOrder(self: EnvironmentService, model: Model): number
	local existing = self.registrationOrderByModel[model]
	if existing then
		return existing
	end
	self.nextRegistrationOrder += 1
	self.registrationOrderByModel[model] = self.nextRegistrationOrder
	return self.nextRegistrationOrder
end

local function modelStableLess(self: EnvironmentService, a: Model, b: Model): boolean
	local aName = a:GetFullName()
	local bName = b:GetFullName()
	if aName ~= bName then
		return aName < bName
	end
	return getModelRegistrationOrder(self, a) < getModelRegistrationOrder(self, b)
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

local function rebuildRooms(self: EnvironmentService): ()
	table.clear(self.rooms)
	table.clear(self.roomModelsByName)

	local models: { Model } = {}
	for model in pairs(self.roomScriptsByModel) do
		table.insert(models, model)
	end
	table.sort(models, function(a: Model, b: Model): boolean
		return modelStableLess(self, a, b)
	end)

	for _, model in ipairs(models) do
		local roomName = self.roomNamesByModel[model]
		local roomScript = self.roomScriptsByModel[model]
		if self.rooms[roomName] == nil then
			self.rooms[roomName] = roomScript
			self.roomModelsByName[roomName] = model
		else
			warn(
				("[CompyAgent:EnvironmentService] Duplicate room %q on %s; using %s"):format(
					roomName,
					model:GetFullName(),
					self.roomModelsByName[roomName]:GetFullName()
				)
			)
		end
	end
end

local function rebuildDoors(self: EnvironmentService): ()
	table.clear(self.doors)
	table.clear(self.doorModelsByName)

	local models: { Model } = {}
	for model in pairs(self.doorScriptsByModel) do
		table.insert(models, model)
	end
	table.sort(models, function(a: Model, b: Model): boolean
		return modelStableLess(self, a, b)
	end)

	for _, model in ipairs(models) do
		local doorName = model.Name
		local doorScript = self.doorScriptsByModel[model]
		if self.doors[doorName] == nil then
			self.doors[doorName] = doorScript
			self.doorModelsByName[doorName] = model
		else
			warn(
				("[CompyAgent:EnvironmentService] Duplicate door model name %q on %s; using %s"):format(
					doorName,
					model:GetFullName(),
					self.doorModelsByName[doorName]:GetFullName()
				)
			)
		end
	end
end

local function releaseRegistrationOrderIfUnused(self: EnvironmentService, part: BasePart): ()
	if self.spawnPointsByPart[part] or self.coverPointsByPart[part] or self.objectivesByPart[part] then
		return
	end
	self.registrationOrderByPart[part] = nil
end

local function releaseModelRegistrationOrderIfUnused(self: EnvironmentService, model: Model): ()
	if self.roomScriptsByModel[model] or self.doorScriptsByModel[model] then
		return
	end
	self.registrationOrderByModel[model] = nil
end

local function getRequiredModule(model: Model, tagName: string): ModuleScript?
	local moduleScript = model:FindFirstChild("Script")
	if not moduleScript or not moduleScript:IsA("ModuleScript") then
		warn(
			("[CompyAgent:EnvironmentService] Ignoring tagged %s without a direct ModuleScript named Script: %s"):format(
				tagName,
				model:GetFullName()
			)
		)
		return nil
	end
	return moduleScript
end

local function loadRoomScript(model: Model, tagName: string): (RoomScript?, string?)
	local moduleScript = getRequiredModule(model, tagName)
	if not moduleScript then
		return nil, nil
	end

	local required, value = pcall(require, moduleScript)
	if not required or typeof(value) ~= "table" then
		warn(("[CompyAgent:EnvironmentService] Failed to require room script %s: %s"):format(moduleScript:GetFullName(), tostring(value)))
		return nil, nil
	end

	local untypedValue = value :: any
	if typeof(untypedValue.GetRoom) ~= "function" or typeof(untypedValue.GetAgents) ~= "function" then
		warn(("[CompyAgent:EnvironmentService] Room script must expose GetRoom and GetAgents: %s"):format(moduleScript:GetFullName()))
		return nil, nil
	end

	local roomOk, roomName = pcall(untypedValue.GetRoom)
	if not roomOk or typeof(roomName) ~= "string" or roomName == "" then
		warn(("[CompyAgent:EnvironmentService] Room script returned an invalid room name: %s"):format(moduleScript:GetFullName()))
		return nil, nil
	end

	local agentsOk, agents = pcall(untypedValue.GetAgents)
	if not agentsOk or typeof(agents) ~= "table" then
		warn(("[CompyAgent:EnvironmentService] Room script returned an invalid agent list: %s"):format(moduleScript:GetFullName()))
		return nil, nil
	end

	return untypedValue :: RoomScript, roomName
end

local function loadDoorScript(model: Model, tagName: string): (DoorScript?, string?)
	local moduleScript = getRequiredModule(model, tagName)
	if not moduleScript then
		return nil, nil
	end

	local required, value = pcall(require, moduleScript)
	if not required or typeof(value) ~= "table" then
		warn(("[CompyAgent:EnvironmentService] Failed to require door script %s: %s"):format(moduleScript:GetFullName(), tostring(value)))
		return nil, nil
	end

	local untypedValue = value :: any
	if typeof(untypedValue.Open) ~= "function"
		or typeof(untypedValue.Close) ~= "function"
		or typeof(untypedValue.GetRoom) ~= "function"
	then
		warn(("[CompyAgent:EnvironmentService] Door script must expose Open, Close, and GetRoom: %s"):format(moduleScript:GetFullName()))
		return nil, nil
	end

	local roomOk, roomName = pcall(untypedValue.GetRoom)
	if not roomOk or typeof(roomName) ~= "string" or roomName == "" then
		warn(("[CompyAgent:EnvironmentService] Door script returned an invalid room name: %s"):format(moduleScript:GetFullName()))
		return nil, nil
	end

	return untypedValue :: DoorScript, roomName
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

local function rankByDistance<T>(records: { T }, origin: Vector3, maxDistance: number, matches: (T) -> boolean, getPosition: (T) -> Vector3): { RankedRecord<T> }
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
	table.insert(
		connections,
		part.Destroying:Connect(function(): ()
			self:UnregisterSpawnPoint(part)
		end)
	)
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
	table.insert(
		connections,
		part.Destroying:Connect(function(): ()
			self:UnregisterCoverPoint(part)
		end)
	)
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
	table.insert(
		connections,
		part.Destroying:Connect(function(): ()
			self:UnregisterObjective(part)
		end)
	)
	return connections
end

local function createRoomConnections(self: EnvironmentService, model: Model): { RBXScriptConnection }
	local connections: { RBXScriptConnection } = {}
	local function refresh(): ()
		self:UnregisterRoom(model)
		if isWorldModel(model) and CollectionService:HasTag(model, self.config.Simulation.RoomTag) then
			self:RegisterRoom(model)
		end
	end

	table.insert(connections, model.ChildAdded:Connect(refresh))
	table.insert(connections, model.ChildRemoved:Connect(refresh))
	table.insert(connections, model.AncestryChanged:Connect(refresh))
	table.insert(
		connections,
		model.Destroying:Connect(function(): ()
			self:UnregisterRoom(model)
		end)
	)
	return connections
end

local function createDoorConnections(self: EnvironmentService, model: Model): { RBXScriptConnection }
	local connections: { RBXScriptConnection } = {}
	local function refresh(): ()
		self:UnregisterDoor(model)
		if isWorldModel(model) and CollectionService:HasTag(model, self.config.Simulation.DoorTag) then
			self:RegisterDoor(model)
		end
	end

	table.insert(connections, model:GetPropertyChangedSignal("Name"):Connect(refresh))
	table.insert(connections, model.ChildAdded:Connect(refresh))
	table.insert(connections, model.ChildRemoved:Connect(refresh))
	table.insert(connections, model.AncestryChanged:Connect(refresh))
	table.insert(
		connections,
		model.Destroying:Connect(function(): ()
			self:UnregisterDoor(model)
		end)
	)
	return connections
end

local function clearRegistryRecords(self: EnvironmentService): ()
	clearPartConnections(self.spawnConnectionsByPart)
	clearPartConnections(self.coverConnectionsByPart)
	clearPartConnections(self.objectiveConnectionsByPart)
	clearModelConnections(self.roomConnectionsByModel)
	clearModelConnections(self.doorConnectionsByModel)
	table.clear(self.spawnPointsByPart)
	table.clear(self.coverPointsByPart)
	table.clear(self.objectivesByPart)
	table.clear(self.roomScriptsByModel)
	table.clear(self.doorScriptsByModel)
	table.clear(self.roomNamesByModel)
	table.clear(self.doorRoomNamesByModel)
	table.clear(self.spawnPoints)
	table.clear(self.coverPoints)
	table.clear(self.objectives)
	table.clear(self.rooms)
	table.clear(self.doors)
	table.clear(self.roomModelsByName)
	table.clear(self.doorModelsByName)
	table.clear(self.agentRoomsByName)
	table.clear(self.registrationOrderByPart)
	table.clear(self.registrationOrderByModel)
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

local function registerTaggedPart(instance: Instance, tagName: string, register: (BasePart) -> ()): ()
	if not instance:IsA("BasePart") then
		warn(("[CompyAgent:EnvironmentService] Ignoring non-BasePart tagged %s: %s"):format(tagName, instance:GetFullName()))
		return
	end
	register(instance)
end

local function registerTaggedModel(instance: Instance, tagName: string, register: (Model) -> ()): ()
	if not instance:IsA("Model") then
		warn(("[CompyAgent:EnvironmentService] Ignoring non-Model tagged %s: %s"):format(tagName, instance:GetFullName()))
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
	for _, instance in ipairs(sortedTaggedInstances(self.config.Simulation.RoomTag)) do
		registerTaggedModel(instance, self.config.Simulation.RoomTag, function(model: Model): ()
			self:RegisterRoom(model)
		end)
	end
	for _, instance in ipairs(sortedTaggedInstances(self.config.Simulation.DoorTag)) do
		registerTaggedModel(instance, self.config.Simulation.DoorTag, function(model: Model): ()
			self:RegisterDoor(model)
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
	local roomTag = self.config.Simulation.RoomTag
	local doorTag = self.config.Simulation.DoorTag

	table.insert(
		self.tagConnections,
		CollectionService:GetInstanceAddedSignal(spawnTag):Connect(function(instance: Instance): ()
			registerTaggedPart(instance, spawnTag, function(part: BasePart): ()
				self:RegisterSpawnPoint(part)
			end)
		end)
	)
	table.insert(
		self.tagConnections,
		CollectionService:GetInstanceRemovedSignal(spawnTag):Connect(function(instance: Instance): ()
			if instance:IsA("BasePart") then
				self:UnregisterSpawnPoint(instance)
			end
		end)
	)

	table.insert(
		self.tagConnections,
		CollectionService:GetInstanceAddedSignal(coverTag):Connect(function(instance: Instance): ()
			registerTaggedPart(instance, coverTag, function(part: BasePart): ()
				self:RegisterCoverPoint(part)
			end)
		end)
	)
	table.insert(
		self.tagConnections,
		CollectionService:GetInstanceRemovedSignal(coverTag):Connect(function(instance: Instance): ()
			if instance:IsA("BasePart") then
				self:UnregisterCoverPoint(instance)
			end
		end)
	)

	table.insert(
		self.tagConnections,
		CollectionService:GetInstanceAddedSignal(objectiveTag):Connect(function(instance: Instance): ()
			registerTaggedPart(instance, objectiveTag, function(part: BasePart): ()
				self:RegisterObjective(part)
			end)
		end)
	)
	table.insert(
		self.tagConnections,
		CollectionService:GetInstanceRemovedSignal(objectiveTag):Connect(function(instance: Instance): ()
			if instance:IsA("BasePart") then
				self:UnregisterObjective(instance)
			end
		end)
	)

	table.insert(
		self.tagConnections,
		CollectionService:GetInstanceAddedSignal(roomTag):Connect(function(instance: Instance): ()
			registerTaggedModel(instance, roomTag, function(model: Model): ()
				self:RegisterRoom(model)
			end)
		end)
	)
	table.insert(
		self.tagConnections,
		CollectionService:GetInstanceRemovedSignal(roomTag):Connect(function(instance: Instance): ()
			if instance:IsA("Model") then
				self:UnregisterRoom(instance)
			end
		end)
	)

	table.insert(
		self.tagConnections,
		CollectionService:GetInstanceAddedSignal(doorTag):Connect(function(instance: Instance): ()
			registerTaggedModel(instance, doorTag, function(model: Model): ()
				self:RegisterDoor(model)
			end)
		end)
	)
	table.insert(
		self.tagConnections,
		CollectionService:GetInstanceRemovedSignal(doorTag):Connect(function(instance: Instance): ()
			if instance:IsA("Model") then
				self:UnregisterDoor(instance)
			end
		end)
	)
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
		enabled = readBoolAttribute(part, "Enabled"),
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

function EnvironmentService.RegisterRoom(self: EnvironmentService, model: Model): RoomScript?
	if not isWorldModel(model) then
		warn(("[CompyAgent:EnvironmentService] Cannot register room outside Workspace: %s"):format(model:GetFullName()))
		return nil
	end

	local roomScript, roomName = loadRoomScript(model, self.config.Simulation.RoomTag)
	if not roomScript or not roomName then
		self:UnregisterRoom(model)
		return nil
	end

	getModelRegistrationOrder(self, model)
	local isNew = self.roomScriptsByModel[model] == nil
	self.roomScriptsByModel[model] = roomScript
	self.roomNamesByModel[model] = roomName
	if isNew then
		self.roomConnectionsByModel[model] = createRoomConnections(self, model)
	end
	rebuildRooms(self)
	return roomScript
end

function EnvironmentService.UnregisterRoom(self: EnvironmentService, model: Model): boolean
	if self.roomScriptsByModel[model] == nil then
		return false
	end
	self.roomScriptsByModel[model] = nil
	self.roomNamesByModel[model] = nil
	disconnectModelConnections(self.roomConnectionsByModel, model)
	releaseModelRegistrationOrderIfUnused(self, model)
	rebuildRooms(self)
	return true
end

function EnvironmentService.RegisterDoor(self: EnvironmentService, model: Model): DoorScript?
	if not isWorldModel(model) then
		warn(("[CompyAgent:EnvironmentService] Cannot register door outside Workspace: %s"):format(model:GetFullName()))
		return nil
	end

	local doorScript, roomName = loadDoorScript(model, self.config.Simulation.DoorTag)
	if not doorScript or not roomName then
		self:UnregisterDoor(model)
		return nil
	end

	getModelRegistrationOrder(self, model)
	local isNew = self.doorScriptsByModel[model] == nil
	self.doorScriptsByModel[model] = doorScript
	self.doorRoomNamesByModel[model] = roomName
	if isNew then
		self.doorConnectionsByModel[model] = createDoorConnections(self, model)
	end
	rebuildDoors(self)
	return doorScript
end

function EnvironmentService.UnregisterDoor(self: EnvironmentService, model: Model): boolean
	if self.doorScriptsByModel[model] == nil then
		return false
	end
	self.doorScriptsByModel[model] = nil
	self.doorRoomNamesByModel[model] = nil
	disconnectModelConnections(self.doorConnectionsByModel, model)
	releaseModelRegistrationOrderIfUnused(self, model)
	rebuildDoors(self)
	return true
end

function EnvironmentService.QueryAllSpawnPoints(self: EnvironmentService, options: SpawnPointQueryOptions?): { SpawnPointRecord }
	local result: { SpawnPointRecord } = {}
	for _, record in ipairs(self.spawnPoints) do
		if not record.enabled then
			continue
		end

		if matchesSpawnOptions(record, options) then
			table.insert(result, record)
		end
	end
	return result
end

function EnvironmentService.QuerySpawnPointsByDistance(self: EnvironmentService, origin: Vector3, maxDistance: number, options: SpawnPointQueryOptions?): { SpawnPointRecord }
	return recordsFromRanked(rankByDistance(self.spawnPoints, origin, maxDistance, function(record: SpawnPointRecord): boolean
		return matchesSpawnOptions(record, options)
	end, function(record: SpawnPointRecord): Vector3
		return record.position
	end))
end

function EnvironmentService.QuerySpawnPointsByRaycast(
	self: EnvironmentService,
	origin: Vector3,
	maxDistance: number,
	raycastParams: RaycastParams?,
	options: SpawnPointQueryOptions?
): { SpawnPointRecord }
	return queryByRaycast(self.spawnPoints, origin, maxDistance, raycastParams, function(record: SpawnPointRecord): boolean
		return matchesSpawnOptions(record, options)
	end, function(record: SpawnPointRecord): BasePart
		return record.part
	end, function(record: SpawnPointRecord): Vector3
		return record.position
	end)
end

function EnvironmentService.QueryAllCoverPoints(self: EnvironmentService, options: CoverPointQueryOptions?): { CoverPointRecord }
	local result: { CoverPointRecord } = {}
	for _, record in ipairs(self.coverPoints) do
		if matchesCoverOptions(record, options) then
			table.insert(result, record)
		end
	end
	return result
end

function EnvironmentService.QueryCoverPointsByDistance(self: EnvironmentService, origin: Vector3, maxDistance: number, options: CoverPointQueryOptions?): { CoverPointRecord }
	return recordsFromRanked(rankByDistance(self.coverPoints, origin, maxDistance, function(record: CoverPointRecord): boolean
		return matchesCoverOptions(record, options)
	end, function(record: CoverPointRecord): Vector3
		return record.position
	end))
end

function EnvironmentService.QueryCoverPointsByRaycast(
	self: EnvironmentService,
	origin: Vector3,
	maxDistance: number,
	raycastParams: RaycastParams?,
	options: CoverPointQueryOptions?
): { CoverPointRecord }
	return queryByRaycast(self.coverPoints, origin, maxDistance, raycastParams, function(record: CoverPointRecord): boolean
		return matchesCoverOptions(record, options)
	end, function(record: CoverPointRecord): BasePart
		return record.part
	end, function(record: CoverPointRecord): Vector3
		return record.position
	end)
end

function EnvironmentService.QueryAllObjectives(self: EnvironmentService, options: ObjectiveQueryOptions?): { ObjectiveRecord }
	local result: { ObjectiveRecord } = {}
	for _, record in ipairs(self.objectives) do
		if matchesObjectiveOptions(record, options) then
			table.insert(result, record)
		end
	end
	return result
end

function EnvironmentService.QueryObjectivesByDistance(self: EnvironmentService, origin: Vector3, maxDistance: number, options: ObjectiveQueryOptions?): { ObjectiveRecord }
	return recordsFromRanked(rankByDistance(self.objectives, origin, maxDistance, function(record: ObjectiveRecord): boolean
		return matchesObjectiveOptions(record, options)
	end, function(record: ObjectiveRecord): Vector3
		return record.position
	end))
end

function EnvironmentService.QueryObjectivesByRaycast(
	self: EnvironmentService,
	origin: Vector3,
	maxDistance: number,
	raycastParams: RaycastParams?,
	options: ObjectiveQueryOptions?
): { ObjectiveRecord }
	return queryByRaycast(self.objectives, origin, maxDistance, raycastParams, function(record: ObjectiveRecord): boolean
		return matchesObjectiveOptions(record, options)
	end, function(record: ObjectiveRecord): BasePart
		return record.part
	end, function(record: ObjectiveRecord): Vector3
		return record.position
	end)
end

function EnvironmentService.QueryAllRooms(self: EnvironmentService): { [string]: RoomScript }
	return table.clone(self.rooms)
end

function EnvironmentService.QueryAllDoors(self: EnvironmentService): { [string]: DoorScript }
	return table.clone(self.doors)
end

function EnvironmentService.GetAgentsInRoom(self: EnvironmentService, roomName: string): { string }
	local roomScript = self.rooms[roomName]
	if not roomScript then
		return {}
	end
	return roomScript.GetAgents()
end

function EnvironmentService.GetAgentRoom(self: EnvironmentService, agentName: string): string
	return self.agentRoomsByName[agentName] or NO_ROOM
end

function EnvironmentService.IsAgentInRoom(self: EnvironmentService, agentName: string): boolean
	return self:GetAgentRoom(agentName) ~= NO_ROOM
end

function EnvironmentService.GetRoomDoors(self: EnvironmentService, roomName: string): { [string]: DoorScript }
	local result: { [string]: DoorScript } = {}
	for doorName, doorScript in pairs(self.doors) do
		local model = self.doorModelsByName[doorName]
		if self.doorRoomNamesByModel[model] == roomName then
			result[doorName] = doorScript
		end
	end
	return result
end

local function updateAgentRooms(self: EnvironmentService): ()
	for agentName in pairs(self.agentRoomsByName) do
		self.agentRoomsByName[agentName] = NO_ROOM
	end

	local roomNames: { string } = {}
	for roomName in pairs(self.rooms) do
		table.insert(roomNames, roomName)
	end
	table.sort(roomNames)

	for _, roomName in ipairs(roomNames) do
		for _, agentName in pairs(self:GetAgentsInRoom(roomName)) do
			if self.agentRoomsByName[agentName] == nil or self.agentRoomsByName[agentName] == NO_ROOM then
				self.agentRoomsByName[agentName] = roomName
			end
		end
	end
end

function EnvironmentService.Update(self: EnvironmentService, deltaTime: number): ()
	if not self.running then
		return
	end
	updateAgentRooms(self)
	self.cleanupElapsed += math.max(0, deltaTime)
	if self.cleanupElapsed < STALE_CLEANUP_INTERVAL then
		return
	end
	self.cleanupElapsed %= STALE_CLEANUP_INTERVAL

	local staleSpawnPoints: { BasePart } = {}
	local staleCoverPoints: { BasePart } = {}
	local staleObjectives: { BasePart } = {}
	local staleRooms: { Model } = {}
	local staleDoors: { Model } = {}
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
	for model in pairs(self.roomScriptsByModel) do
		if not isWorldModel(model) then
			table.insert(staleRooms, model)
		end
	end
	for model in pairs(self.doorScriptsByModel) do
		if not isWorldModel(model) then
			table.insert(staleDoors, model)
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
	for _, model in ipairs(staleRooms) do
		self:UnregisterRoom(model)
	end
	for _, model in ipairs(staleDoors) do
		self:UnregisterDoor(model)
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

local singleton: EnvironmentService = setmetatable({
	config = Config,
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
	rooms = {},
	doors = {},
	agentRoomsByName = {},
	roomScriptsByModel = {},
	doorScriptsByModel = {},
	roomNamesByModel = {},
	doorRoomNamesByModel = {},
	roomModelsByName = {},
	doorModelsByName = {},
	spawnConnectionsByPart = {},
	coverConnectionsByPart = {},
	objectiveConnectionsByPart = {},
	roomConnectionsByModel = {},
	doorConnectionsByModel = {},
	registrationOrderByModel = {},
}, EnvironmentService)

return singleton
