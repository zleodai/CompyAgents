--[=[
	AgentModelTests

	Verifies the empty humanoid model shell and store mappings used by spatial
	mode adapters.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local CompyServerScripts = ServerScriptService.CompyAgent
local Config = require(CompyServerScripts.Core.Config)
local Types = require(CompyServerScripts.Core.Types)
local AgentState = require(CompyServerScripts.Agents.AgentState)
local AgentModelFactory = require(CompyServerScripts.Agents.AgentModelFactory)
local AgentModelStore = require(CompyServerScripts.Agents.AgentModelStore)

local AgentModelTests: { Types.TestCase } = {}

local MODEL_FOLDER = "CompyAgentModelTests"

local function createTestConfig(): Types.Config
	local config: Types.Config = table.clone(Config)
	config.AgentModel = table.clone(Config.AgentModel)
	config.AgentModel.FolderName = MODEL_FOLDER
	return config
end

local function cleanup(): ()
	local existing = Workspace:FindFirstChild(MODEL_FOLDER)
	if existing then
		existing:Destroy()
	end

	local source = Workspace:FindFirstChild("CompyAgentModelTestSource")
	if source then
		source:Destroy()
	end
end

local function createSourceHumanoidModel(name: string): Types.StudioHumanoidModel
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = Workspace

	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = model

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Anchored = true
	rootPart.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Anchored = true
	head.Parent = model

	local upperTorso = Instance.new("Part")
	upperTorso.Name = "UpperTorso"
	upperTorso.Anchored = true
	upperTorso.Parent = model

	model.PrimaryPart = rootPart

	return {
		model = model,
		humanoid = humanoid,
		rootPart = rootPart,
		teamId = "Blue",
		frequency = 3,
	}
end

table.insert(AgentModelTests, {
	name = "AgentModelFactory creates fallback minimal humanoid model parts",
	run = function(context: Types.TestContext): ()
		cleanup()

		local config = createTestConfig()
		local agent = AgentState.create("Blue_01", "Blue", Vector3.new(4, 0, 8), Vector3.new(1, 0, 0))
		local factory = AgentModelFactory.new(config)
		local record = factory:Create(agent)

		context.Assert(record.model:IsA("Model"), "factory should create a Model")
		context.Assert(record.humanoid:IsA("Humanoid"), "factory should create a Humanoid")
		context.Assert(record.rootPart.Name == "HumanoidRootPart", "factory should create HumanoidRootPart")
		context.Assert(record.head.Name == "Head", "factory should create Head")
		context.Assert(record.model.PrimaryPart == record.rootPart, "model PrimaryPart should be HumanoidRootPart")
		context.Assert(record.rootPart.CanCollide, "root part should collide for humanoid movement")
		context.Assert(not record.rootPart.Anchored, "root part should be unanchored")
		context.Assert(not record.head.CanCollide, "head should not collide")
		context.Assert(not record.isStudioModel, "fallback model should be marked as generated")
		context.AssertEqual(record.groundToRootOffset, config.AgentModel.RootPartSize.Y * 0.5, "fallback should offset root above ground")
		context.Assert(record.humanoid.HipHeight == config.AgentModel.HipHeight, "humanoid should use configured HipHeight")
		context.Assert(record.humanoid.WalkSpeed == config.AgentModel.WalkSpeed, "humanoid should use configured WalkSpeed")
		context.Assert(record.head.Parent == record.model, "head should be parented into model")

		record.model:Destroy()
		cleanup()
	end,
})

table.insert(AgentModelTests, {
	name = "AgentModelFactory clones Studio humanoid source model",
	run = function(context: Types.TestContext): ()
		cleanup()

		local config = createTestConfig()
		local sourceRecord = createSourceHumanoidModel("CompyAgentModelTestSource")
		local agent = AgentState.create("Blue_StudioModel", "Blue", Vector3.new(12, 0, 18), Vector3.new(0, 0, 1))
		local factory = AgentModelFactory.new(config)
		local record = factory:Create(agent, nil, sourceRecord)

		context.Assert(record.model ~= sourceRecord.model, "factory should clone the Studio source model")
		context.Assert(record.model.Name == agent.id, "clone should be renamed to the agent id")
		context.Assert(record.humanoid ~= sourceRecord.humanoid, "clone should use a cloned Humanoid")
		context.Assert(record.rootPart.Name == "HumanoidRootPart", "clone should keep HumanoidRootPart")
		context.Assert(record.head.Name == "Head", "clone should keep Head")
		context.Assert(record.model:FindFirstChild("UpperTorso") ~= nil, "clone should preserve R15 body parts")
		context.Assert(record.model.PrimaryPart == record.rootPart, "clone should set PrimaryPart to the root part")
		context.Assert(record.isStudioModel, "clone should be marked as a Studio model")
		context.Assert(record.groundToRootOffset > 0, "clone should record source root height above ground")
		context.Assert(record.rootPart.Position.Y > agent.transform.position.Y, "clone root should spawn above ground")
		context.Assert(not record.rootPart.Anchored, "clone root part should be unanchored for movement")
		context.Assert(not record.head.Anchored, "clone head should be unanchored for movement")
		context.Assert(record.humanoid.WalkSpeed == config.AgentModel.WalkSpeed, "clone humanoid should use WalkSpeed config")

		record.model:Destroy()
		cleanup()
	end,
})

table.insert(AgentModelTests, {
	name = "AgentModelStore stores and retrieves model handles by agent id",
	run = function(context: Types.TestContext): ()
		cleanup()

		local config = createTestConfig()
		local store = AgentModelStore.new(config)
		local agent = AgentState.create("Red_01", "Red", Vector3.new(-4, 0, -8), Vector3.new(-1, 0, 0))
		local record = store:CreateForAgent(agent)

		context.Assert(record ~= nil, "store should create a record when AgentModel is enabled")
		if record == nil then
			return
		end

		context.Assert(store:Get(agent.id) == record, "store should retrieve the full record")
		context.Assert(store:GetModel(agent.id) == record.model, "store should retrieve the model")
		context.Assert(store:GetHumanoid(agent.id) == record.humanoid, "store should retrieve the humanoid")
		context.Assert(store:GetRootPart(agent.id) == record.rootPart, "store should retrieve the root part")
		context.Assert(store:GetHead(agent.id) == record.head, "store should retrieve the head")
		context.Assert(record.model.Parent == store:GetModelFolder(), "model should be parented to the configured folder")

		store:DestroyAll()
		cleanup()
	end,
})

table.insert(AgentModelTests, {
	name = "AgentModelStore hides humanoid model on death",
	run = function(context: Types.TestContext): ()
		cleanup()

		local config = createTestConfig()
		local store = AgentModelStore.new(config)
		local agent = AgentState.create("Blue_HideModel", "Blue", Vector3.new(0, 0, 0), Vector3.new(0, 0, 1))
		local record = store:CreateForAgent(agent)

		context.Assert(record ~= nil, "store should create a record before hiding it")
		if record == nil then
			return
		end

		store:HideModel(agent.id)

		context.Assert(record.hidden, "hidden model record should be marked hidden")
		for _, descendant in ipairs(record.model:GetDescendants()) do
			if descendant:IsA("BasePart") then
				context.AssertEqual(descendant.Transparency, 1, "hidden model parts should be invisible")
				context.Assert(not descendant.CanCollide, "hidden model parts should not collide")
				context.Assert(not descendant.CanTouch, "hidden model parts should not touch")
				context.Assert(not descendant.CanQuery, "hidden model parts should not be queryable")
			end
		end

		store:DestroyAll()
		cleanup()
	end,
})

table.insert(AgentModelTests, {
	name = "AgentModelStore chooses and clones team Studio humanoid models",
	run = function(context: Types.TestContext): ()
		cleanup()

		local config = createTestConfig()
		local sourceRecord = createSourceHumanoidModel("CompyAgentModelTestSource")
		local registry = {
			GetHumanoidModels = function(_self: Types.StudioWorldRegistry, teamId: Types.TeamId?): { Types.StudioHumanoidModel }
				context.AssertEqual(teamId, "Blue", "store should query humanoid models for the agent team")
				return { sourceRecord }
			end,
		} :: any

		local store = AgentModelStore.new(config, registry)
		local agent = AgentState.create("Blue_StoreModel", "Blue", Vector3.new(0, 0, 20), Vector3.new(0, 0, 1))
		local record = store:CreateForAgent(agent)

		context.Assert(record ~= nil, "store should create a cloned Studio humanoid record")
		if record == nil then
			return
		end

		context.Assert(record.model ~= sourceRecord.model, "store should clone rather than move source model")
		context.Assert(sourceRecord.model.Parent == Workspace, "source model should remain in Studio location")
		context.Assert(record.model.Parent == store:GetModelFolder(), "clone should be parented to model store folder")
		context.Assert(record.model:FindFirstChild("UpperTorso") ~= nil, "store clone should preserve R15 body parts")

		store:DestroyAll()
		cleanup()
	end,
})

return AgentModelTests
