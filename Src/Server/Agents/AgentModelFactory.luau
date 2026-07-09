local AgentModelFactory = {}
AgentModelFactory.__index = AgentModelFactory

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Types = require(CompyServerScripts.Core.Types)

local function createPart(name: string, size: Vector3, cframe: CFrame, color: Color3, transparency: number): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Transparency = transparency
	part.Anchored = false
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

function AgentModelFactory:Create(agentState: Types.AgentState, spawnCFrame: CFrame): Model
	local model = Instance.new("Model")
	model.Name = agentState.id

	local teamConfig = self.config.Teams[agentState.teamId]
	local color = teamConfig and teamConfig.Color or Color3.fromRGB(180, 180, 180)
	local root = createPart(
		"HumanoidRootPart",
		self.config.Agent.RootPartSize,
		spawnCFrame + Vector3.new(0, self.config.Agent.HipHeight, 0),
		color,
		self.config.Agent.DebugTransparency
	)
	local head = createPart(
		"Head",
		self.config.Agent.HeadSize,
		root.CFrame + self.config.Agent.HeadOffset,
		color,
		0
	)
	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.HipHeight = self.config.Agent.HipHeight
	humanoid.WalkSpeed = self.config.Agent.WalkSpeed

	root.Parent = model
	head.Parent = model
	humanoid.Parent = model
	model.PrimaryPart = root

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = head
	weld.Parent = root

	model:PivotTo(root.CFrame)

	agentState.model = model
	agentState.humanoid = humanoid
	agentState.rootPart = root
	agentState.head = head

	return model
end

function AgentModelFactory.new(config: Types.Config): Types.AgentModelFactory
	local self = setmetatable({}, AgentModelFactory)
	self.config = config
	return self
end

return AgentModelFactory
