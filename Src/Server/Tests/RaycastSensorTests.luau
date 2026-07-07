--[=[
	RaycastSensorTests

	Covers model-head ray origins/targets with fallback-compatible setup.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local CompyServerScripts = ServerScriptService.CompyAgent
local Config = require(CompyServerScripts.Core.Config)
local Types = require(CompyServerScripts.Core.Types)
local AgentState = require(CompyServerScripts.Agents.AgentState)
local AgentStore = require(CompyServerScripts.Agents.AgentStore)
local AgentModelStore = require(CompyServerScripts.Agents.AgentModelStore)
local BlackboardStore = require(CompyServerScripts.Blackboard.BlackboardStore)
local RaycastSensor = require(CompyServerScripts.Adapters.Sensors.RaycastSensor)
local SpatialWorldQuery = require(CompyServerScripts.Adapters.World.SpatialWorldQuery)

local RaycastSensorTests: { Types.TestCase } = {}

local MODEL_FOLDER = "CompyAgentRaycastSensorModels"
local VISUALIZATION_FOLDER = "CompyAgentRaycastSensorVisualization"

local function createTestConfig(): Types.Config
	local config: Types.Config = table.clone(Config)
	config.AgentModel = table.clone(Config.AgentModel)
	config.Sensor = table.clone(Config.Sensor)
	config.Visualization = table.clone(Config.Visualization)
	config.AgentModel.FolderName = MODEL_FOLDER
	config.AgentModel.HeadOffset = Vector3.new(0, 10, 0)
	config.Sensor.EyeOffset = Vector3.new(0, 2.5, 0)
	config.Visualization.FolderName = VISUALIZATION_FOLDER
	return config
end

local function cleanup(): ()
	for _, folderName in ipairs({ MODEL_FOLDER, VISUALIZATION_FOLDER }) do
		local existing = Workspace:FindFirstChild(folderName)
		if existing then
			existing:Destroy()
		end
	end

	local blocker = Workspace:FindFirstChild("CompyAgentRaycastSensorBlocker")
	if blocker then
		blocker:Destroy()
	end
end

table.insert(RaycastSensorTests, {
	name = "RaycastSensor uses head LOS and grounded blackboard sightings when model data exists",
	run = function(context: Types.TestContext): ()
		cleanup()

		local config = createTestConfig()
		local agentStore = AgentStore.new()
		local modelStore = AgentModelStore.new(config)
		local worldQuery = SpatialWorldQuery.new(config)
		local blackboard = BlackboardStore.new("Blue")
		local blue = AgentState.create("Blue_HeadRay", "Blue", Vector3.new(0, 0, 0), Vector3.new(0, 0, 1))
		local red = AgentState.create("Red_HeadRay", "Red", Vector3.new(0, 0, 20), Vector3.new(0, 0, -1))

		agentStore:Add(blue)
		agentStore:Add(red)
		modelStore:CreateForAgent(blue)
		local redRecord = modelStore:CreateForAgent(red)

		local blocker = Instance.new("Part")
		blocker.Name = "CompyAgentRaycastSensorBlocker"
		blocker.Anchored = true
		blocker.Size = Vector3.new(8, 4, 1)
		blocker.CFrame = CFrame.new(0, 2.5, 10)
		blocker.Parent = Workspace

		local sensor = RaycastSensor.new(config, modelStore)
		local result = sensor:Sense(blue, worldQuery, agentStore, blackboard, 10)

		context.AssertEqual(#result.visibleEnemies, 1, "head-height ray should see over fallback-height blocker")
		if redRecord then
			local sighting = blackboard:GetBestEnemySighting()
			local expectedSightingPosition = redRecord.rootPart.Position - Vector3.new(0, redRecord.groundToRootOffset, 0)

			context.Assert(
				result.visibleEnemies[1].position == redRecord.head.Position,
				"visible contact position should use target Head position"
			)
			context.Assert(sighting ~= nil, "blackboard should receive a sighting")
			context.Assert(
				sighting ~= nil and (sighting.position - expectedSightingPosition).Magnitude <= 0.001,
				"blackboard sighting should use grounded target position"
			)
		end

		modelStore:DestroyAll()
		cleanup()
	end,
})

return RaycastSensorTests
