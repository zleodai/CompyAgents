--!strict

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local CompyServerScripts = ServerScriptService.CompyAgent
local SPHController = require(CompyServerScripts.Integrations.Spearhead.SPHController)

local SPHAgentFactory = {}
SPHAgentFactory.__index = SPHAgentFactory

export type Config = {
	parent: Instance?,
	maxHealth: number?,
	controllerConfig: SPHController.Config?,
}

type FactoryData = {
	parent: Instance,
	maxHealth: number,
	controllerConfig: SPHController.Config,
}

export type SPHAgentFactory = typeof(setmetatable({} :: FactoryData, SPHAgentFactory))

local function mergeControllerConfig(
	defaults: SPHController.Config,
	overrides: SPHController.Config?
): SPHController.Config
	local merged = table.clone(defaults)
	if overrides then
		for key, value in overrides do
			merged[key] = value
		end
	end
	return merged
end

function SPHAgentFactory.Create(
	self: SPHAgentFactory,
	name: string,
	spawnCFrame: CFrame,
	controllerOverrides: SPHController.Config?
): SPHController.SPHController
	assert(self.parent:FindFirstChild(name) == nil, `{self.parent:GetFullName()} already contains {name}`)

	local description = Instance.new("HumanoidDescription")
	local character = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
	description:Destroy()
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
	humanoid.MaxHealth = self.maxHealth
	humanoid.Health = self.maxHealth
	humanoid.DisplayName = name

	return SPHController.new(character, mergeControllerConfig(self.controllerConfig, controllerOverrides))
end

function SPHAgentFactory.new(config: Config?): SPHAgentFactory
	local factoryConfig = config or {}
	return setmetatable({
		parent = factoryConfig.parent or Workspace,
		maxHealth = math.max(1, factoryConfig.maxHealth or 100),
		controllerConfig = table.clone(factoryConfig.controllerConfig or {}),
	}, SPHAgentFactory)
end

return SPHAgentFactory
