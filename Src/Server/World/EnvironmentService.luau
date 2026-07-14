--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CompySharedScripts = ReplicatedStorage.CompyAgent
local _DefaultConfig = require(CompySharedScripts.Config)

local EnvironmentService = {}
EnvironmentService.__index = EnvironmentService

local TWO_PI = math.pi * 2

type HumanoidModelRecord = {
	name: string,
	teamId: string?,
	model: Model,
	humanoid: Humanoid,
	rootPart: BasePart?,
	frequency: number,
}

type EnvironmentServiceData = {
	config: typeof(_DefaultConfig),
	spawnPoints: {
		{
			name: string,
			teamId: string?,
			cframe: CFrame,
			position: Vector3,
			facing: Vector3,
			spawnOrder: number,
			spawnRadius: number,
			squadId: string?,
		}
	},
	coverPoints: {
		{
			name: string,
			coverId: string,
			teamId: string?,
			position: Vector3,
			posture: string,
			quality: number,
			facing: Vector3,
		}
	},
	objectives: {
		{
			name: string,
			objectiveId: string,
			teamId: string?,
			cframe: CFrame,
			position: Vector3,
			radius: number,
		}
	},
	humanoidModels: { HumanoidModelRecord },
}

export type EnvironmentService = typeof(setmetatable({} :: EnvironmentServiceData, EnvironmentService))

local function readTeamId(instance: Instance): string?
	local value = instance:GetAttribute("TeamId")
	return if typeof(value) == "string" then value else nil
end

local function readNumber(instance: Instance, name: string, defaultValue: number): number
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else defaultValue
end

local function readString(instance: Instance, name: string, defaultValue: string?): string?
	local value = instance:GetAttribute(name)
	return if typeof(value) == "string" then value else defaultValue
end

local function readSpawnRadius(instance: Instance): number
	local value = instance:GetAttribute("SpawnRadius")
	if typeof(value) ~= "number" then
		value = instance:GetAttribute("spawnRadius")
	end
	return if typeof(value) == "number" then value else 0
end

local function readCoverFacing(instance: BasePart): Vector3
	local x = instance:GetAttribute("FacingX")
	local y = instance:GetAttribute("FacingY")
	local z = instance:GetAttribute("FacingZ")
	if typeof(x) == "number" and typeof(y) == "number" and typeof(z) == "number" then
		local facing = Vector3.new(x, y, z)
		if facing.Magnitude > 0.001 then
			return facing.Unit
		end
	end
	return instance.CFrame.LookVector
end

local function readPosture(instance: Instance): string
	local value = instance:GetAttribute("Posture")
	return if typeof(value) == "string" then value else "Crouching"
end

local function matchesTeam(recordTeamId: string?, teamId: string?): boolean
	return teamId == nil or recordTeamId == nil or recordTeamId == teamId
end

function EnvironmentService.Refresh(self: EnvironmentService): ()
	table.clear(self.spawnPoints)
	table.clear(self.coverPoints)
	table.clear(self.objectives)
	table.clear(self.humanoidModels)

	if not self.config.Simulation.UseStudioLevel then
		return
	end

	for _, instance in ipairs(CollectionService:GetTagged(self.config.Simulation.SpawnTag)) do
		if instance:IsA("BasePart") then
			table.insert(self.spawnPoints, {
				name = instance.Name,
				teamId = readTeamId(instance),
				cframe = instance.CFrame,
				position = instance.Position,
				facing = instance.CFrame.LookVector,
				spawnOrder = readNumber(instance, "SpawnOrder", 0),
				spawnRadius = readSpawnRadius(instance),
				squadId = readString(instance, "SquadId", nil),
			})
		end
	end

	for _, instance in ipairs(CollectionService:GetTagged(self.config.Simulation.CoverTag)) do
		if instance:IsA("BasePart") then
			table.insert(self.coverPoints, {
				name = instance.Name,
				coverId = readString(instance, "CoverId", instance.Name) or instance.Name,
				teamId = readTeamId(instance),
				position = instance.Position,
				posture = readPosture(instance),
				quality = readNumber(instance, "CoverQuality", 1),
				facing = readCoverFacing(instance),
			})
		end
	end

	for _, instance in ipairs(CollectionService:GetTagged(self.config.Simulation.ObjectiveTag)) do
		if instance:IsA("BasePart") then
			table.insert(self.objectives, {
				name = instance.Name,
				objectiveId = readString(instance, "ObjectiveId", instance.Name) or instance.Name,
				teamId = readTeamId(instance),
				cframe = instance.CFrame,
				position = instance.Position,
				radius = readNumber(instance, "Radius", math.max(instance.Size.X, instance.Size.Z) * 0.5),
			})
		end
	end

	for _, instance in ipairs(CollectionService:GetTagged(self.config.Simulation.HumanoidTag)) do
		if instance:IsA("Model") then
			local humanoid = instance:FindFirstChildOfClass("Humanoid")
			if not humanoid then
				continue
			end
			local rootPart = instance:FindFirstChild("HumanoidRootPart")
			table.insert(self.humanoidModels, {
				name = instance.Name,
				teamId = readTeamId(instance),
				model = instance,
				humanoid = humanoid,
				rootPart = if rootPart and rootPart:IsA("BasePart") then rootPart else nil,
				frequency = math.max(0, readNumber(instance, "Frequency", 1)),
			})
		end
	end

	table.sort(self.spawnPoints, function(a, b): boolean
		return if a.spawnOrder == b.spawnOrder then a.name < b.name else a.spawnOrder < b.spawnOrder
	end)
	table.sort(self.coverPoints, function(a, b): boolean
		return a.name < b.name
	end)
	table.sort(self.objectives, function(a, b): boolean
		return a.name < b.name
	end)
	table.sort(self.humanoidModels, function(a, b): boolean
		return a.name < b.name
	end)
end

function EnvironmentService.GetSpawnCFrame(self: EnvironmentService, teamId: string, index: number): CFrame
	local matching: { typeof(self.spawnPoints[1]) } = {}
	for _, spawnPoint in ipairs(self.spawnPoints) do
		if matchesTeam(spawnPoint.teamId, teamId) then
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
	if not self.config.Simulation.UseConfigSpawnsFallback then
		error(`No Studio spawn is available for team {teamId}`)
	end

	local teamConfig = self.config.Teams[teamId]
	assert(teamConfig, `Missing team config for {teamId}`)
	local position = teamConfig.SpawnOrigin + Vector3.new(0, 0, (index - 1) * teamConfig.SpawnSpacing)
	return CFrame.lookAt(position, position + teamConfig.Forward)
end

function EnvironmentService.GetCoverPositions(
	self: EnvironmentService,
	teamId: string,
	posture: string
): { Vector3 }
	local positions: { Vector3 } = {}
	for _, coverPoint in ipairs(self.coverPoints) do
		if matchesTeam(coverPoint.teamId, teamId) and coverPoint.posture == posture then
			table.insert(positions, coverPoint.position)
		end
	end
	return positions
end

function EnvironmentService.GetObjectivePositions(self: EnvironmentService, teamId: string): { Vector3 }
	local positions: { Vector3 } = {}
	for _, objective in ipairs(self.objectives) do
		if matchesTeam(objective.teamId, teamId) then
			table.insert(positions, objective.position)
		end
	end
	return positions
end

function EnvironmentService.GetHumanoidModels(
	self: EnvironmentService,
	teamId: string?
): { HumanoidModelRecord }
	local models: { HumanoidModelRecord } = {}
	for _, record in ipairs(self.humanoidModels) do
		if matchesTeam(record.teamId, teamId) then
			table.insert(models, record)
		end
	end
	return models
end

function EnvironmentService.CreateAgentCharacter(
	self: EnvironmentService,
	teamId: string,
	index: number,
	name: string,
	spawnCFrame: CFrame,
	parent: Instance
): Model
	local candidates: { typeof(self.humanoidModels[1]) } = {}
	local totalFrequency = 0
	for _, record in ipairs(self.humanoidModels) do
		if matchesTeam(record.teamId, teamId) and record.frequency > 0 then
			table.insert(candidates, record)
			totalFrequency += record.frequency
		end
	end

	local template: Model? = nil
	if totalFrequency > 0 then
		local selection = (((index - 1) * 0.61803398875) % 1) * totalFrequency
		local cumulative = 0
		for _, record in ipairs(candidates) do
			cumulative += record.frequency
			if selection <= cumulative then
				template = record.model
				break
			end
		end
	end

	local character: Model
	if template then
		character = template:Clone()
	else
		local description = Instance.new("HumanoidDescription")
		character = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
		description:Destroy()
	end

	character.Name = name
	CollectionService:RemoveTag(character, self.config.Simulation.HumanoidTag)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		character.PrimaryPart = rootPart
	end
	character:PivotTo(spawnCFrame)
	character.Parent = parent
	return character
end

function EnvironmentService.RaycastLineOfSight(
	_self: EnvironmentService,
	fromPosition: Vector3,
	toPosition: Vector3,
	ignore: { Instance },
	targetModel: Model?
): (boolean, Vector3)
	local direction = toPosition - fromPosition
	if direction.Magnitude <= 0.001 then
		return true, toPosition
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore

	local result = Workspace:Raycast(fromPosition, direction, params)
	if not result then
		return true, toPosition
	end
	if targetModel and result.Instance:IsDescendantOf(targetModel) then
		return true, result.Position
	end
	if (result.Position - toPosition).Magnitude <= 1.5 then
		return true, result.Position
	end
	return false, result.Position
end

function EnvironmentService.new(config: typeof(_DefaultConfig)): EnvironmentService
	return setmetatable({
		config = config,
		spawnPoints = {},
		coverPoints = {},
		objectives = {},
		humanoidModels = {},
	}, EnvironmentService)
end

return EnvironmentService
