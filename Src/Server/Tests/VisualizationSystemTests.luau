--[=[
	VisualizationSystemTests

	Verifies path visualization ownership stays with NoobPath in spatial
	NoobPath mode while grid mode keeps the custom destination marker/line.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local CompyServerScripts = ServerScriptService.CompyAgent
local Config = require(CompyServerScripts.Core.Config)
local Types = require(CompyServerScripts.Core.Types)
local AgentState = require(CompyServerScripts.Agents.AgentState)
local AgentStore = require(CompyServerScripts.Agents.AgentStore)
local AgentModelStore = require(CompyServerScripts.Agents.AgentModelStore)
local VisualizationSystem = require(CompyServerScripts.Systems.VisualizationSystem)

local VisualizationSystemTests: { Types.TestCase } = {}

local VISUALIZATION_FOLDER = "CompyAgentVisualizationSystemTests"
local MODEL_FOLDER = "CompyAgentVisualizationSystemModels"

local function createTestConfig(mode: "Grid" | "Spatial", noobPathEnabled: boolean): Types.Config
	local config: Types.Config = table.clone(Config)
	config.SimulationMode = mode
	config.AgentModel = table.clone(Config.AgentModel)
	config.NoobPath = table.clone(Config.NoobPath)
	config.Visualization = table.clone(Config.Visualization)
	config.Cadence = table.clone(Config.Cadence)
	config.AgentModel.FolderName = MODEL_FOLDER
	config.Visualization.FolderName = VISUALIZATION_FOLDER
	config.NoobPath.Enabled = noobPathEnabled
	config.Cadence.VisualizationInterval = 0
	return config
end

local function cleanup(): ()
	for _, folderName in ipairs({ VISUALIZATION_FOLDER, MODEL_FOLDER }) do
		local existing = Workspace:FindFirstChild(folderName)
		if existing then
			existing:Destroy()
		end
	end
end

local function createSystem(config: Types.Config, agentStore: Types.AgentStore): Types.VisualizationSystem
	local agentModelStore = AgentModelStore.new(config)
	local system = VisualizationSystem.new({
		config = config,
		agentStore = agentStore,
		agentModelStore = agentModelStore,
	})

	system:Initialize()
	return system
end

table.insert(VisualizationSystemTests, {
	name = "VisualizationSystem bypasses custom path visuals in spatial NoobPath mode",
	run = function(context: Types.TestContext): ()
		cleanup()

		local config = createTestConfig("Spatial", true)
		local agentStore = AgentStore.new()
		local agent = AgentState.create("Blue_NoobPathVisual", "Blue", Vector3.new(0, 0, 0), Vector3.new(0, 0, 1))
		agent.movement.destination = Vector3.new(0, 0, 12)
		agentStore:Add(agent)

		local system = createSystem(config, agentStore)
		system:Step(1, 1)

		local folder = Workspace:FindFirstChild(VISUALIZATION_FOLDER)
		context.Assert(folder ~= nil, "visualization folder should exist")
		if folder then
			context.Assert(
				folder:FindFirstChild(agent.id .. "_PathDestination") == nil,
				"NoobPath mode should not create custom destination markers"
			)
			context.Assert(
				folder:FindFirstChild(agent.id .. "_PathLine") == nil,
				"NoobPath mode should not create custom destination lines"
			)
		end

		system.agentModelStore:DestroyAll()
		cleanup()
	end,
})

table.insert(VisualizationSystemTests, {
	name = "VisualizationSystem keeps custom path visuals in grid mode",
	run = function(context: Types.TestContext): ()
		cleanup()

		local config = createTestConfig("Grid", false)
		local agentStore = AgentStore.new()
		local agent = AgentState.create("Blue_GridVisual", "Blue", Vector3.new(0, 0, 0), Vector3.new(0, 0, 1))
		agent.movement.destination = Vector3.new(0, 0, 12)
		agentStore:Add(agent)

		local system = createSystem(config, agentStore)
		system:Step(1, 1)

		local folder = Workspace:FindFirstChild(VISUALIZATION_FOLDER)
		context.Assert(folder ~= nil, "visualization folder should exist")
		if folder then
			context.Assert(
				folder:FindFirstChild(agent.id .. "_PathDestination") ~= nil,
				"grid mode should create the custom destination marker"
			)
			context.Assert(
				folder:FindFirstChild(agent.id .. "_PathLine") ~= nil,
				"grid mode should create the custom destination line"
			)
		end

		system.agentModelStore:DestroyAll()
		cleanup()
	end,
})

return VisualizationSystemTests
