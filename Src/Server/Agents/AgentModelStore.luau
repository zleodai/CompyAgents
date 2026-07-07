--[=[
	AgentModelStore

	Owns the Roblox humanoid model handles associated with data-first agents.
	Systems ask this store for model parts instead of searching Workspace.
]=]

local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local AgentModelFactory = require(CompyServerScripts.Agents.AgentModelFactory)

local AgentModelStore = {}
AgentModelStore.__index = AgentModelStore

local function safeFacing(facing: Vector3): Vector3
	local flatFacing = Vector3.new(facing.X, 0, facing.Z)
	if flatFacing.Magnitude <= 0.001 then
		return Vector3.new(0, 0, -1)
	end

	return flatFacing.Unit
end

function AgentModelStore:Initialize(): ()
	if not self.config.AgentModel.Enabled then
		return
	end

	local existing = Workspace:FindFirstChild(self.config.AgentModel.FolderName)
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = self.config.AgentModel.FolderName
	folder.Parent = Workspace
	self.folder = folder
end

local function chooseHumanoidModel(records: { Types.StudioHumanoidModel }): Types.StudioHumanoidModel?
	local total = 0
	for _, record in ipairs(records) do
		total += record.frequency
	end

	if total <= 0 then
		return nil
	end

	local roll = math.random() * total
	local running = 0

	for _, record in ipairs(records) do
		running += record.frequency
		if roll <= running then
			return record
		end
	end

	return records[#records]
end

function AgentModelStore:_chooseSourceModel(agent: Types.Agent): Types.StudioHumanoidModel?
	local registry = self.studioWorldRegistry
	if not registry then
		return nil
	end

	return chooseHumanoidModel(registry:GetHumanoidModels(agent.teamId))
end

function AgentModelStore:CreateForAgent(agent: Types.Agent, spawnCFrame: CFrame?): Types.AgentModelRecord?
	if not self.config.AgentModel.Enabled then
		return nil
	end

	if self.records[agent.id] then
		return self.records[agent.id]
	end

	if not self.folder then
		self:Initialize()
	end

	local record = self.factory:Create(agent, spawnCFrame, self:_chooseSourceModel(agent))
	record.model.Parent = self.folder
	self.records[agent.id] = record

	return record
end

function AgentModelStore:Get(agentId: Types.AgentId): Types.AgentModelRecord?
	return self.records[agentId]
end

function AgentModelStore:GetModel(agentId: Types.AgentId): Model?
	local record = self:Get(agentId)
	return if record then record.model else nil
end

function AgentModelStore:GetHumanoid(agentId: Types.AgentId): Humanoid?
	local record = self:Get(agentId)
	return if record then record.humanoid else nil
end

function AgentModelStore:GetRootPart(agentId: Types.AgentId): BasePart?
	local record = self:Get(agentId)
	return if record then record.rootPart else nil
end

function AgentModelStore:GetHead(agentId: Types.AgentId): BasePart?
	local record = self:Get(agentId)
	return if record then record.head else nil
end

function AgentModelStore:GetModelFolder(): Folder?
	return self.folder
end

function AgentModelStore:GetModels(): { Model }
	local models: { Model } = {}

	for _, record in pairs(self.records) do
		table.insert(models, record.model)
	end

	return models
end

function AgentModelStore:SyncModelToAgent(agent: Types.Agent): ()
	local record = self.records[agent.id]
	if not record or record.hidden then
		return
	end

	local facing = safeFacing(agent.transform.facing)
	local rootCFrame = CFrame.lookAt(agent.transform.position, agent.transform.position + facing)
	record.model:PivotTo(rootCFrame + Vector3.new(0, record.groundToPivotOffset, 0))
end

function AgentModelStore:HideModel(agentId: Types.AgentId): ()
	local record = self.records[agentId]
	if not record or record.hidden then
		return
	end

	record.hidden = true

	for _, descendant in ipairs(record.model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			descendant.Transparency = 1
		elseif descendant:IsA("BillboardGui") then
			descendant.Enabled = false
		end
	end
end

function AgentModelStore:DestroyAll(): ()
	for agentId, record in pairs(self.records) do
		record.model:Destroy()
		self.records[agentId] = nil
	end

	if self.folder then
		self.folder:Destroy()
		self.folder = nil
	end
end

function AgentModelStore.new(config: Types.Config, studioWorldRegistry: Types.StudioWorldRegistry?): Types.AgentModelStore
	local self = setmetatable({}, AgentModelStore)

	self.config = config
	self.factory = AgentModelFactory.new(config)
	self.studioWorldRegistry = studioWorldRegistry
	self.records = {}
	self.folder = nil

	self:Initialize()

	return self
end

return AgentModelStore
