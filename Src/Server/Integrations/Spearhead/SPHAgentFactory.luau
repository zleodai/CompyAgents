--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CompyServerScripts = ServerScriptService.CompyAgent
local CompySharedScripts = ReplicatedStorage.CompyAgent
local Config = require(ReplicatedStorage.CompyAgent.Config)
local SPHController = require(CompyServerScripts.Integrations.Spearhead.SPHController)
local Team = require(CompySharedScripts.Team)

local Configs = require(CompySharedScripts.Config)

local SPHAgentFactory = {}
SPHAgentFactory.__index = SPHAgentFactory

export type AgentConfig = {
	teamId: Team.Id,
	maxHealth: number?,
	controllerConfig: SPHController.Config?,
}

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
local DEFAULT_CONFIG = {
	teamId = "Blue",
	health = Config.Agent.MaxHealth,
	controllerConfig = Configs.Agent.ControllerConfig :: { [any]: any },
} :: AgentConfig

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

local function mergeConfig(defaults: { [any]: any }, overrides: { [any]: any }?): { [any]: any }
	local merged = table.clone(defaults)
	if overrides then
		for key, value in overrides do
			merged[key] = value
		end
	end
	return merged
end

function SPHAgentFactory.Create(name: string, spawnCFrame: CFrame, config: AgentConfig): SPHController.SPHController
	local mergedConfig = mergeConfig(DEFAULT_CONFIG, config) :: AgentConfig

	local defaultControllerConfig = DEFAULT_CONFIG.controllerConfig or {}
	local mergedControllerConfig = mergeConfig(defaultControllerConfig, config.controllerConfig) :: SPHController.Config

	local gunOptions = { "AKM", "M4A1" }
	mergedControllerConfig.weaponName = gunOptions[math.random(1, #gunOptions)]

	local modelName = DEFAULT_MODEL_NAME

	local modelOptions = Configs.Teams[mergedConfig.teamId].Models
	if modelOptions then
		modelName = modelOptions[math.random(1, #modelOptions)]
	end

	local character = resolveModelTemplate(modelName):Clone()
	character.Name = name

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	assert(rootPart and rootPart:IsA("BasePart"), `{character:GetFullName()} is missing HumanoidRootPart`)
	character.PrimaryPart = rootPart
	character.Parent = Workspace
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
	humanoid.MaxHealth = mergedConfig.maxHealth or Configs.Agent.MaxHealth
	humanoid.Health = mergedConfig.maxHealth or Configs.Agent.MaxHealth
	humanoid.DisplayName = name

	local constructed, controllerOrError = pcall(function(): SPHController.SPHController
		return SPHController.new(character, mergedConfig.teamId, mergedControllerConfig)
	end)
	if not constructed then
		character:Destroy()
		error(controllerOrError, 0)
	end
	return controllerOrError :: SPHController.SPHController
end

return SPHAgentFactory
