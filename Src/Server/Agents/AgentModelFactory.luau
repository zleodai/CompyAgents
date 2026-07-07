--[=[
	AgentModelFactory

	Creates the agent-owned humanoid model used by spatial perception, NoobPath
	movement, and model-backed debug visualization. Studio-authored R15 models
	are cloned when available, with the generated shell kept as a fallback.
]=]

local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local AgentModelFactory = {}
AgentModelFactory.__index = AgentModelFactory

local function safeFacing(facing: Vector3): Vector3
	local flatFacing = Vector3.new(facing.X, 0, facing.Z)
	if flatFacing.Magnitude <= 0.001 then
		return Vector3.new(0, 0, -1)
	end

	return flatFacing.Unit
end

local function getSpawnCFrame(agent: Types.Agent, overrideCFrame: CFrame?): CFrame
	if overrideCFrame then
		return overrideCFrame
	end

	local facing = safeFacing(agent.transform.facing)
	return CFrame.lookAt(agent.transform.position, agent.transform.position + facing)
end

local function getModelBottomY(model: Model): number
	local boundingCFrame, boundingSize = model:GetBoundingBox()
	return boundingCFrame.Position.Y - boundingSize.Y * 0.5
end

local function getGroundOffsets(model: Model, rootPart: BasePart): (number, number)
	local bottomY = getModelBottomY(model)
	local groundToPivotOffset = math.max(0, model:GetPivot().Position.Y - bottomY)
	local groundToRootOffset = math.max(0, rootPart.Position.Y - bottomY)

	return groundToPivotOffset, groundToRootOffset
end

local function getGroundedPivotCFrame(agent: Types.Agent, spawnCFrame: CFrame?, groundToPivotOffset: number): CFrame
	return getSpawnCFrame(agent, spawnCFrame) + Vector3.new(0, groundToPivotOffset, 0)
end

local function configureModelPart(part: BasePart, size: Vector3, color: Color3, transparency: number): ()
	part.Anchored = false
	part.CanTouch = false
	part.CanQuery = true
	part.CastShadow = false
	part.Massless = false
	part.Size = size
	part.Color = color
	part.Transparency = transparency
end

local function findHumanoid(model: Model): Humanoid?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return humanoid
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Humanoid") then
			return descendant
		end
	end

	return nil
end

local function findBasePartByName(model: Model, name: string): BasePart?
	local child = model:FindFirstChild(name, true)
	if child and child:IsA("BasePart") then
		return child
	end

	return nil
end

local function findRootPart(model: Model, sourceRecord: Types.StudioHumanoidModel): BasePart?
	local humanoidRootPart = findBasePartByName(model, "HumanoidRootPart")
	if humanoidRootPart then
		return humanoidRootPart
	end

	if sourceRecord.rootPart then
		local clonedSourceRoot = findBasePartByName(model, sourceRecord.rootPart.Name)
		if clonedSourceRoot then
			return clonedSourceRoot
		end
	end

	return model.PrimaryPart
end

local function unanchorModel(model: Model): ()
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
		end
	end
end

function AgentModelFactory:_createEmptyModel(agent: Types.Agent, spawnCFrame: CFrame?): Types.AgentModelRecord
	local model = Instance.new("Model")
	model.Name = agent.id

	local humanoidRootPart = Instance.new("Part")
	humanoidRootPart.Name = "HumanoidRootPart"
	configureModelPart(
		humanoidRootPart,
		self.config.AgentModel.RootPartSize,
		self.config.Teams[agent.teamId].Color,
		self.config.AgentModel.DebugTransparency
	)
	humanoidRootPart.CanCollide = true
	humanoidRootPart.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	configureModelPart(
		head,
		self.config.AgentModel.HeadSize,
		self.config.Teams[agent.teamId].Color,
		self.config.AgentModel.DebugTransparency
	)
	head.CanCollide = false
	head.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Name = "HeadWeld"
	weld.Part0 = humanoidRootPart
	weld.Part1 = head
	weld.Parent = humanoidRootPart

	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.HipHeight = self.config.AgentModel.HipHeight
	humanoid.WalkSpeed = self.config.AgentModel.WalkSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	model.PrimaryPart = humanoidRootPart
	local groundToRootOffset = self.config.AgentModel.RootPartSize.Y * 0.5
	local groundToPivotOffset = groundToRootOffset
	local rootCFrame = getGroundedPivotCFrame(agent, spawnCFrame, groundToPivotOffset)
	humanoidRootPart.CFrame = rootCFrame
	head.CFrame = rootCFrame + self.config.AgentModel.HeadOffset
	model:PivotTo(rootCFrame)

	return {
		model = model,
		humanoid = humanoid,
		rootPart = humanoidRootPart,
		head = head,
		isStudioModel = false,
		groundToPivotOffset = groundToPivotOffset,
		groundToRootOffset = groundToRootOffset,
		hidden = false,
	}
end

function AgentModelFactory:_createFromStudioModel(
	agent: Types.Agent,
	spawnCFrame: CFrame?,
	sourceRecord: Types.StudioHumanoidModel
): Types.AgentModelRecord?
	local model = sourceRecord.model:Clone()
	model.Name = agent.id
	CollectionService:RemoveTag(model, self.config.Level.HumanoidTag)

	local humanoid = findHumanoid(model)
	local rootPart = findRootPart(model, sourceRecord)
	local head = findBasePartByName(model, "Head")

	if not humanoid or not rootPart or not head then
		warn(
			("[CompyAgent:AgentModelFactory] Ignoring invalid humanoid source %s for %s; Humanoid=%s Root=%s Head=%s"):format(
				sourceRecord.model:GetFullName(),
				agent.id,
				tostring(humanoid ~= nil),
				tostring(rootPart ~= nil),
				tostring(head ~= nil)
			)
		)
		model:Destroy()
		return nil
	end

	unanchorModel(model)
	rootPart.CanQuery = true
	head.CanCollide = false
	head.CanQuery = true

	humanoid.WalkSpeed = self.config.AgentModel.WalkSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	model.PrimaryPart = rootPart
	local groundToPivotOffset, groundToRootOffset = getGroundOffsets(model, rootPart)
	model:PivotTo(getGroundedPivotCFrame(agent, spawnCFrame, groundToPivotOffset))

	return {
		model = model,
		humanoid = humanoid,
		rootPart = rootPart,
		head = head,
		isStudioModel = true,
		groundToPivotOffset = groundToPivotOffset,
		groundToRootOffset = groundToRootOffset,
		hidden = false,
	}
end

function AgentModelFactory:Create(
	agent: Types.Agent,
	spawnCFrame: CFrame?,
	sourceRecord: Types.StudioHumanoidModel?
): Types.AgentModelRecord
	if sourceRecord then
		local record = self:_createFromStudioModel(agent, spawnCFrame, sourceRecord)
		if record then
			return record
		end
	end

	return self:_createEmptyModel(agent, spawnCFrame)
end

function AgentModelFactory.new(config: Types.Config): Types.AgentModelFactory
	local self = setmetatable({}, AgentModelFactory)

	self.config = config

	return self
end

return AgentModelFactory
