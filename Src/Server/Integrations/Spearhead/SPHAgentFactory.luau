--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CompyServerScripts = ServerScriptService.CompyAgent
local CompySharedScripts = ReplicatedStorage.CompyAgent
local SPHController = require(CompyServerScripts.Integrations.Spearhead.SPHController)
local Team = require(CompySharedScripts.Team)

local SPHAgentFactory = {}
SPHAgentFactory.__index = SPHAgentFactory

export type Config = {
	teamId: Team.Id,
	parent: Instance?,
	maxHealth: number?,
	controllerConfig: SPHController.Config?,
}

type FactoryData = {
	teamId: Team.Id,
	parent: Instance,
	maxHealth: number,
	controllerConfig: SPHController.Config,
}

export type SPHAgentFactory = typeof(setmetatable({} :: FactoryData, SPHAgentFactory))

local DEFAULT_MODEL_NAME = "Doge"
local REQUIRED_R6_PARTS = {
	"HumanoidRootPart",
	"Head",
	"Torso",
	"Left Arm",
	"Right Arm",
	"Left Leg",
	"Right Leg",
}

local function resolveModelTemplate(modelName: string): Model
	assert(modelName ~= "", "controllerConfig.modelName must not be empty")
	local compyAgent = Workspace:FindFirstChild("CompyAgent")
	assert(compyAgent, "Workspace.CompyAgent is missing")
	local models = compyAgent:FindFirstChild("Models")
	assert(models and models:IsA("Folder"), "Workspace.CompyAgent.Models must be a Folder")
	local template = models:FindFirstChild(modelName)
	assert(template and template:IsA("Model"), `Workspace.CompyAgent.Models is missing the Model {modelName}`)
	assert(template.Archivable, `{template:GetFullName()} must be Archivable`)
	local humanoid = template:FindFirstChildOfClass("Humanoid")
	assert(humanoid, `{template:GetFullName()} is missing a Humanoid`)
	assert(humanoid.RigType == Enum.HumanoidRigType.R6, `{template:GetFullName()} must use an R6 Humanoid`)
	for _, partName in REQUIRED_R6_PARTS do
		local part = template:FindFirstChild(partName)
		assert(part and part:IsA("BasePart"), `{template:GetFullName()} is missing the R6 part {partName}`)
	end
	return template
end

local function mergeControllerConfig(defaults: SPHController.Config, overrides: SPHController.Config?): SPHController.Config
	local merged = table.clone(defaults)
	if overrides then
		for key, value in overrides do
			merged[key] = value
		end
	end
	return merged
end

function SPHAgentFactory.Create(self: SPHAgentFactory, name: string, spawnCFrame: CFrame, controllerOverrides: SPHController.Config?): SPHController.SPHController
	assert(self.parent:FindFirstChild(name) == nil, `{self.parent:GetFullName()} already contains {name}`)

	local mergedControllerConfig = mergeControllerConfig(self.controllerConfig, controllerOverrides)

	local modelName = DEFAULT_MODEL_NAME

	local modelOptions = mergedControllerConfig.modelNames
	if modelOptions then
		modelName = modelOptions[math.random(1, #modelOptions)]
	end

	local character = resolveModelTemplate(modelName):Clone()
	character.Name = name
	character.Parent = self.parent

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	assert(rootPart and rootPart:IsA("BasePart"), `{character:GetFullName()} is missing HumanoidRootPart`)
	character.PrimaryPart = rootPart
	character:PivotTo(spawnCFrame)

	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			local canSetOwner = descendant:CanSetNetworkOwnership()
			if canSetOwner then
				descendant:SetNetworkOwner(nil)
			end
		end
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	assert(humanoid, `{character:GetFullName()} is missing a Humanoid`)
	assert(humanoid.RigType == Enum.HumanoidRigType.R6, `{character:GetFullName()} must use an R6 Humanoid`)
	humanoid.MaxHealth = self.maxHealth
	humanoid.Health = self.maxHealth
	humanoid.DisplayName = name

	local constructed, controllerOrError = pcall(function(): SPHController.SPHController
		return SPHController.new(character, self.teamId, mergedControllerConfig)
	end)
	if not constructed then
		character:Destroy()
		error(controllerOrError, 0)
	end
	return controllerOrError :: SPHController.SPHController
end

function SPHAgentFactory.new(config: Config): SPHAgentFactory
	assert(config.teamId ~= "", "SPHAgentFactory teamId must not be empty")
	local factoryConfig = config
	local controllerConfig = table.clone(factoryConfig.controllerConfig or {})
	return setmetatable({
		teamId = factoryConfig.teamId,
		parent = factoryConfig.parent or Workspace,
		maxHealth = math.max(1, factoryConfig.maxHealth or 100),
		controllerConfig = controllerConfig,
	}, SPHAgentFactory)
end

return SPHAgentFactory
