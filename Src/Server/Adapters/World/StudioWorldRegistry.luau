--[=[
	StudioWorldRegistry

	Snapshots tagged Studio-authored level objects into typed records that the
	data-first simulation can query without scanning Roblox Instances mid-frame.
]=]

local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local StudioWorldRegistry = {}
StudioWorldRegistry.__index = StudioWorldRegistry

local function readStringAttribute(instance: Instance, attributeName: string): string?
	local value = instance:GetAttribute(attributeName)

	if typeof(value) == "string" and value ~= "" then
		return value
	end

	return nil
end

local function readOptionalNumberAttribute(instance: Instance, attributeName: string): number?
	local value = instance:GetAttribute(attributeName)

	if typeof(value) == "number" then
		return value
	end

	return nil
end

local function readNumberAttribute(instance: Instance, attributeName: string, defaultValue: number): number
	local value = readOptionalNumberAttribute(instance, attributeName)

	if value ~= nil then
		return value
	end

	return defaultValue
end

local function readSpawnRadiusAttribute(instance: Instance): number
	local radius = readOptionalNumberAttribute(instance, "SpawnRadius")
	if radius ~= nil then
		return radius
	end

	return readOptionalNumberAttribute(instance, "spawnRadius") or 0
end

local function readFacingAttribute(instance: Instance): Vector3?
	local x = readOptionalNumberAttribute(instance, "FacingX")
	local y = readOptionalNumberAttribute(instance, "FacingY")
	local z = readOptionalNumberAttribute(instance, "FacingZ")

	if x == nil or y == nil or z == nil then
		return nil
	end

	local facing = Vector3.new(x, y, z)
	if facing.Magnitude <= 0 then
		return nil
	end

	return facing.Unit
end

local function getPartFromTaggedInstance(instance: Instance, tagName: string): BasePart?
	if instance:IsA("BasePart") then
		return instance
	end

	warn(("[CompyAgent:StudioWorldRegistry] Ignoring non-BasePart tagged %s: %s"):format(tagName, instance:GetFullName()))
	return nil
end

local function matchesTeam(recordTeamId: Types.TeamId?, teamId: Types.TeamId?): boolean
	if teamId == nil then
		return true
	end

	return recordTeamId == nil or recordTeamId == teamId
end

local function sortSpawnPoints(spawnPoints: { Types.StudioSpawnPoint }): ()
	table.sort(spawnPoints, function(a: Types.StudioSpawnPoint, b: Types.StudioSpawnPoint): boolean
		if a.spawnOrder == b.spawnOrder then
			return a.part:GetFullName() < b.part:GetFullName()
		end

		return a.spawnOrder < b.spawnOrder
	end)
end

local function sortNamedParts<T>(items: { T }, getName: (T) -> string): ()
	table.sort(items, function(a: T, b: T): boolean
		return getName(a) < getName(b)
	end)
end

function StudioWorldRegistry:_readSpawnPoint(part: BasePart): Types.StudioSpawnPoint
	return {
		part = part,
		teamId = readStringAttribute(part, "TeamId"),
		squadId = readStringAttribute(part, "SquadId"),
		spawnOrder = readNumberAttribute(part, "SpawnOrder", 0),
		spawnRadius = readSpawnRadiusAttribute(part),
		cframe = part.CFrame,
		position = part.Position,
		facing = part.CFrame.LookVector,
	}
end

function StudioWorldRegistry:_readCoverPoint(part: BasePart): Types.StudioCoverPoint
	return {
		part = part,
		coverId = readStringAttribute(part, "CoverId") or part.Name,
		coverQuality = readNumberAttribute(part, "CoverQuality", 1),
		teamId = readStringAttribute(part, "TeamId"),
		cframe = part.CFrame,
		position = part.Position,
		facing = readFacingAttribute(part) or part.CFrame.LookVector,
	}
end

function StudioWorldRegistry:_readObjective(part: BasePart): Types.StudioObjective
	return {
		part = part,
		objectiveId = readStringAttribute(part, "ObjectiveId") or part.Name,
		teamId = readStringAttribute(part, "TeamId"),
		radius = readNumberAttribute(part, "Radius", math.max(part.Size.X, part.Size.Z) / 2),
		cframe = part.CFrame,
		position = part.Position,
	}
end

function StudioWorldRegistry:Refresh(): ()
	table.clear(self.spawnPoints)
	table.clear(self.coverPoints)
	table.clear(self.objectives)

	for _, instance in ipairs(CollectionService:GetTagged(self.config.Level.SpawnTag)) do
		local part = getPartFromTaggedInstance(instance, self.config.Level.SpawnTag)
		if part then
			table.insert(self.spawnPoints, self:_readSpawnPoint(part))
		end
	end

	for _, instance in ipairs(CollectionService:GetTagged(self.config.Level.CoverTag)) do
		local part = getPartFromTaggedInstance(instance, self.config.Level.CoverTag)
		if part then
			table.insert(self.coverPoints, self:_readCoverPoint(part))
		end
	end

	for _, instance in ipairs(CollectionService:GetTagged(self.config.Level.ObjectiveTag)) do
		local part = getPartFromTaggedInstance(instance, self.config.Level.ObjectiveTag)
		if part then
			table.insert(self.objectives, self:_readObjective(part))
		end
	end

	sortSpawnPoints(self.spawnPoints)
	sortNamedParts(self.coverPoints, function(point: Types.StudioCoverPoint): string
		return point.coverId
	end)
	sortNamedParts(self.objectives, function(objective: Types.StudioObjective): string
		return objective.objectiveId
	end)
end

function StudioWorldRegistry:GetSpawnPoints(teamId: Types.TeamId?): { Types.StudioSpawnPoint }
	local result: { Types.StudioSpawnPoint } = {}

	for _, spawnPoint in ipairs(self.spawnPoints) do
		if matchesTeam(spawnPoint.teamId, teamId) then
			table.insert(result, spawnPoint)
		end
	end

	return result
end

function StudioWorldRegistry:GetCoverPoints(teamId: Types.TeamId?): { Types.StudioCoverPoint }
	local result: { Types.StudioCoverPoint } = {}

	for _, coverPoint in ipairs(self.coverPoints) do
		if matchesTeam(coverPoint.teamId, teamId) then
			table.insert(result, coverPoint)
		end
	end

	return result
end

function StudioWorldRegistry:GetObjectives(teamId: Types.TeamId?): { Types.StudioObjective }
	local result: { Types.StudioObjective } = {}

	for _, objective in ipairs(self.objectives) do
		if matchesTeam(objective.teamId, teamId) then
			table.insert(result, objective)
		end
	end

	return result
end

function StudioWorldRegistry.new(config: Types.Config): Types.StudioWorldRegistry
	local self = setmetatable({}, StudioWorldRegistry)

	self.config = config
	self.spawnPoints = {}
	self.coverPoints = {}
	self.objectives = {}

	self:Refresh()

	return self
end

return StudioWorldRegistry
