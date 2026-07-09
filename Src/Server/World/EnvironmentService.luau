local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local CompyServerScripts = ServerScriptService.CompyAgent

local Types = require(CompyServerScripts.Core.Types)

local EnvironmentService = {}
EnvironmentService.__index = EnvironmentService

local TWO_PI = math.pi * 2

local function readTeamId(instance: Instance): string?
	local value = instance:GetAttribute("TeamId")
	if typeof(value) == "string" then
		return value
	end
	return nil
end

local function readNumber(instance: Instance, name: string, defaultValue: number): number
	local value = instance:GetAttribute(name)
	if typeof(value) == "number" then
		return value
	end
	return defaultValue
end

local function sortByName(records: { Types.CoverPoint } | { Types.ObjectivePoint }): ()
	table.sort(records, function(a: Types.CoverPoint | Types.ObjectivePoint, b: Types.CoverPoint | Types.ObjectivePoint): boolean
		return a.name < b.name
	end)
end

function EnvironmentService:Refresh(): ()
	table.clear(self.spawnPoints)
	table.clear(self.coverPoints)
	table.clear(self.objectives)

	for _, instance in ipairs(CollectionService:GetTagged(self.config.Simulation.SpawnTag)) do
		if instance:IsA("BasePart") then
			table.insert(self.spawnPoints, {
				name = instance.Name,
				teamId = readTeamId(instance),
				cframe = instance.CFrame,
				position = instance.Position,
				facing = instance.CFrame.LookVector,
				spawnOrder = readNumber(instance, "SpawnOrder", 0),
				spawnRadius = readNumber(instance, "SpawnRadius", 0),
			})
		end
	end

	for _, instance in ipairs(CollectionService:GetTagged(self.config.Simulation.CoverTag)) do
		if instance:IsA("BasePart") then
			table.insert(self.coverPoints, {
				name = instance.Name,
				teamId = readTeamId(instance),
				position = instance.Position,
			})
		end
	end

	for _, instance in ipairs(CollectionService:GetTagged(self.config.Simulation.ObjectiveTag)) do
		if instance:IsA("BasePart") then
			table.insert(self.objectives, {
				name = instance.Name,
				teamId = readTeamId(instance),
				position = instance.Position,
			})
		end
	end

	table.sort(self.spawnPoints, function(a: Types.SpawnPoint, b: Types.SpawnPoint): boolean
		if a.spawnOrder == b.spawnOrder then
			return a.name < b.name
		end
		return a.spawnOrder < b.spawnOrder
	end)
	sortByName(self.coverPoints)
	sortByName(self.objectives)
end

function EnvironmentService:GetSpawnCFrame(teamId: string, index: number): CFrame
	local matching = {}
	for _, spawnPoint in ipairs(self.spawnPoints) do
		if spawnPoint.teamId == nil or spawnPoint.teamId == teamId then
			table.insert(matching, spawnPoint)
		end
	end

	if #matching > 0 then
		local spawnPoint = matching[((index - 1) % #matching) + 1]
		local position = spawnPoint.position
		if spawnPoint.spawnRadius > 0 then
			local angle = math.random() * TWO_PI
			local distance = math.sqrt(math.random()) * spawnPoint.spawnRadius
			position += Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		end
		return CFrame.lookAt(position, position + spawnPoint.facing)
	end

	local teamConfig = self.config.Teams[teamId]
	local sideOffset = (index - 1) * teamConfig.SpawnSpacing
	local position = teamConfig.SpawnOrigin + Vector3.new(0, 0, sideOffset)
	return CFrame.lookAt(position, position + teamConfig.Forward)
end

function EnvironmentService:GetNearestCover(position: Vector3, teamId: string): Vector3?
	local bestPosition = nil
	local bestDistance = math.huge

	for _, coverPoint in ipairs(self.coverPoints) do
		if coverPoint.teamId == nil or coverPoint.teamId == teamId then
			local distance = (coverPoint.position - position).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				bestPosition = coverPoint.position
			end
		end
	end

	return bestPosition
end

function EnvironmentService:ClampDestination(destination: Vector3): Vector3
	return destination
end

function EnvironmentService:RaycastLineOfSight(
	fromPosition: Vector3,
	toPosition: Vector3,
	ignore: { Instance }?
): (boolean, Vector3)
	local direction = toPosition - fromPosition
	if direction.Magnitude <= 0.001 then
		return true, toPosition
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore or {}

	local result = Workspace:Raycast(fromPosition, direction, params)
	if result then
		return false, result.Position
	end

	return true, toPosition
end

function EnvironmentService:HasLineOfSight(fromPosition: Vector3, toPosition: Vector3, ignore: { Instance }?): boolean
	local hasLineOfSight, _raycastEnd = self:RaycastLineOfSight(fromPosition, toPosition, ignore)
	return hasLineOfSight
end

function EnvironmentService.new(config: Types.Config): Types.EnvironmentService
	local self = setmetatable({}, EnvironmentService)
	self.config = config
	self.spawnPoints = {}
	self.coverPoints = {}
	self.objectives = {}
	return self
end

return EnvironmentService
