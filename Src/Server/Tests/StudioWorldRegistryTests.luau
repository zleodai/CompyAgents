--[=[
	StudioWorldRegistryTests

	Exercises Studio-authored level registry parsing through Roblox runtime APIs
	and verifies Simulation still falls back to config spawns when no tagged
	spawn points exist.
]=]

local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local CompyServerScripts = ServerScriptService.CompyAgent
local Config = require(CompyServerScripts.Core.Config)
local Types = require(CompyServerScripts.Core.Types)
local Simulation = require(CompyServerScripts.Core.Simulation)
local StudioWorldRegistry = require(CompyServerScripts.Adapters.World.StudioWorldRegistry)

local StudioWorldRegistryTests: { Types.TestCase } = {}

local SPAWN_TAG = "CompyAgentTestSpawn"
local COVER_TAG = "CompyAgentTestCover"
local OBJECTIVE_TAG = "CompyAgentTestObjective"
local HUMANOID_TAG = "CompyAgentTestHumanoid"
local EMPTY_SPAWN_TAG = "CompyAgentTestEmptySpawn"

local function cleanupTaggedInstances(tags: { string }): ()
	for _, tagName in ipairs(tags) do
		for _, instance in ipairs(CollectionService:GetTagged(tagName)) do
			CollectionService:RemoveTag(instance, tagName)
			instance:Destroy()
		end
	end
end

local function createTestConfig(spawnTag: string): Types.Config
	local config: Types.Config = table.clone(Config)

	config.Level = {
		UseStudioLevel = true,
		UseConfigSpawnsFallback = true,
		SpawnTag = spawnTag,
		CoverTag = COVER_TAG,
		ObjectiveTag = OBJECTIVE_TAG,
		HumanoidTag = HUMANOID_TAG,
	}

	return config
end

local function createTaggedPart(name: string, tagName: string, cframe: CFrame): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CFrame = cframe
	part.Parent = Workspace

	CollectionService:AddTag(part, tagName)

	return part
end

local function createTaggedHumanoidModel(name: string, tagName: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = Workspace

	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = model

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Anchored = true
	rootPart.Parent = model

	CollectionService:AddTag(model, tagName)

	return model
end

local function withSimulationConfig(levelConfig: Types.LevelConfig, bootstrapEnabled: boolean, callback: () -> ()): ()
	local previousLevel = Config.Level
	local previousBootstrapEnabled = Config.AgentBootstrap.Enabled

	Config.Level = levelConfig
	Config.AgentBootstrap.Enabled = bootstrapEnabled

	local ok, failureMessage = pcall(callback)

	Config.Level = previousLevel
	Config.AgentBootstrap.Enabled = previousBootstrapEnabled

	if not ok then
		error(tostring(failureMessage), 2)
	end
end

table.insert(StudioWorldRegistryTests, {
	name = "StudioWorldRegistry parses and sorts tagged spawn points",
	run = function(context: Types.TestContext): ()
		cleanupTaggedInstances({ SPAWN_TAG, COVER_TAG, OBJECTIVE_TAG, HUMANOID_TAG })

		local first = createTaggedPart("BlueFirst", SPAWN_TAG, CFrame.new(10, 2, 3) * CFrame.Angles(0, math.rad(90), 0))
		first:SetAttribute("TeamId", "Blue")
		first:SetAttribute("SpawnOrder", 1)
		first:SetAttribute("SquadId", "Alpha")
		first:SetAttribute("SpawnRadius", 8)

		local second = createTaggedPart("BlueSecond", SPAWN_TAG, CFrame.new(20, 2, 3))
		second:SetAttribute("TeamId", "Blue")
		second:SetAttribute("SpawnOrder", 2)

		local red = createTaggedPart("RedFirst", SPAWN_TAG, CFrame.new(-10, 2, 3))
		red:SetAttribute("TeamId", "Red")
		red:SetAttribute("SpawnOrder", 1)

		local registry = StudioWorldRegistry.new(createTestConfig(SPAWN_TAG))
		local blueSpawns = registry:GetSpawnPoints("Blue")

		context.AssertEqual(#blueSpawns, 2, "Blue team should read two spawn points")
		context.AssertEqual(blueSpawns[1].teamId, "Blue", "spawn should read TeamId")
		context.AssertEqual(blueSpawns[1].spawnOrder, 1, "spawn should read SpawnOrder")
		context.AssertEqual(blueSpawns[1].squadId, "Alpha", "spawn should read SquadId")
		context.AssertEqual(blueSpawns[1].spawnRadius, 8, "spawn should read SpawnRadius")
		context.AssertEqual(blueSpawns[2].spawnRadius, 0, "spawn without SpawnRadius should use zero radius")
		context.Assert(blueSpawns[1].cframe == first.CFrame, "spawn should record CFrame")
		context.Assert(blueSpawns[1].position == first.Position, "spawn should record Position")
		context.Assert(blueSpawns[1].facing == first.CFrame.LookVector, "spawn should use part LookVector as facing")
		context.Assert(blueSpawns[2].part == second, "spawn order should sort ascending by SpawnOrder")

		local redSpawns = registry:GetSpawnPoints("Red")
		context.AssertEqual(#redSpawns, 1, "Red team should read one spawn point")
		context.Assert(redSpawns[1].part == red, "Red spawn should return the tagged Red part")

		cleanupTaggedInstances({ SPAWN_TAG, COVER_TAG, OBJECTIVE_TAG, HUMANOID_TAG })
	end,
})

table.insert(StudioWorldRegistryTests, {
	name = "Simulation uses SpawnRadius for Studio spawn positions",
	run = function(context: Types.TestContext): ()
		cleanupTaggedInstances({ SPAWN_TAG, COVER_TAG, OBJECTIVE_TAG, HUMANOID_TAG })

		local blue = createTaggedPart("BlueRadiusSpawn", SPAWN_TAG, CFrame.new(100, 5, 200))
		blue:SetAttribute("TeamId", "Blue")
		blue:SetAttribute("SpawnRadius", 12)

		local red = createTaggedPart("RedExactSpawn", SPAWN_TAG, CFrame.new(-100, 5, -200))
		red:SetAttribute("TeamId", "Red")

		local levelConfig: Types.LevelConfig = {
			UseStudioLevel = true,
			UseConfigSpawnsFallback = true,
			SpawnTag = SPAWN_TAG,
			CoverTag = COVER_TAG,
			ObjectiveTag = OBJECTIVE_TAG,
			HumanoidTag = HUMANOID_TAG,
		}

		withSimulationConfig(levelConfig, false, function(): ()
			local simulation = Simulation.new()

			simulation:_spawnDemoAgents(1)

			local blueAgent = simulation.agentStore:GetTeam("Blue")[1]
			local redAgent = simulation.agentStore:GetTeam("Red")[1]

			context.Assert(blueAgent ~= nil, "Blue agent should spawn from Studio point")
			context.Assert(redAgent ~= nil, "Red agent should spawn from Studio point")
			if blueAgent == nil or redAgent == nil then
				return
			end

			local blueOffset = blueAgent.transform.position - blue.Position
			local blueHorizontalDistance = Vector3.new(blueOffset.X, 0, blueOffset.Z).Magnitude

			context.Assert(blueHorizontalDistance <= 12, "Blue agent should spawn within SpawnRadius")
			context.AssertEqual(blueAgent.transform.position.Y, blue.Position.Y, "SpawnRadius should not change spawn height")
			context.Assert(redAgent.transform.position == red.Position, "Spawn without SpawnRadius should use exact position")
		end)

		cleanupTaggedInstances({ SPAWN_TAG, COVER_TAG, OBJECTIVE_TAG, HUMANOID_TAG })
	end,
})

table.insert(StudioWorldRegistryTests, {
	name = "Simulation cycles team agents across available Studio spawn points",
	run = function(context: Types.TestContext): ()
		cleanupTaggedInstances({ SPAWN_TAG, COVER_TAG, OBJECTIVE_TAG, HUMANOID_TAG })

		local blue = createTaggedPart("BlueOnlySpawn", SPAWN_TAG, CFrame.new(10, 2, 30))
		blue:SetAttribute("TeamId", "Blue")
		blue:SetAttribute("SpawnOrder", 1)

		local redFirst = createTaggedPart("RedFirstSpawn", SPAWN_TAG, CFrame.new(-10, 2, -30))
		redFirst:SetAttribute("TeamId", "Red")
		redFirst:SetAttribute("SpawnOrder", 1)

		local redSecond = createTaggedPart("RedSecondSpawn", SPAWN_TAG, CFrame.new(-20, 2, -30))
		redSecond:SetAttribute("TeamId", "Red")
		redSecond:SetAttribute("SpawnOrder", 2)

		local levelConfig: Types.LevelConfig = {
			UseStudioLevel = true,
			UseConfigSpawnsFallback = true,
			SpawnTag = SPAWN_TAG,
			CoverTag = COVER_TAG,
			ObjectiveTag = OBJECTIVE_TAG,
			HumanoidTag = HUMANOID_TAG,
		}

		withSimulationConfig(levelConfig, false, function(): ()
			local simulation = Simulation.new()

			simulation:_spawnDemoAgents(4)

			local blueAgents = simulation.agentStore:GetTeam("Blue")
			local redAgents = simulation.agentStore:GetTeam("Red")

			context.AssertEqual(#blueAgents, 4, "Blue should spawn all requested agents from one spawn point")
			context.AssertEqual(#redAgents, 4, "Red should spawn all requested agents across two spawn points")

			for _, agent in ipairs(blueAgents) do
				context.Assert(agent.transform.position == blue.Position, "single Blue spawn should receive every Blue agent")
			end

			context.Assert(redAgents[1].transform.position == redFirst.Position, "first Red agent should use first spawn")
			context.Assert(redAgents[2].transform.position == redSecond.Position, "second Red agent should use second spawn")
			context.Assert(redAgents[3].transform.position == redFirst.Position, "third Red agent should cycle to first spawn")
			context.Assert(redAgents[4].transform.position == redSecond.Position, "fourth Red agent should cycle to second spawn")
		end)

		cleanupTaggedInstances({ SPAWN_TAG, COVER_TAG, OBJECTIVE_TAG, HUMANOID_TAG })
	end,
})

table.insert(StudioWorldRegistryTests, {
	name = "StudioWorldRegistry parses tagged humanoid models",
	run = function(context: Types.TestContext): ()
		cleanupTaggedInstances({ SPAWN_TAG, COVER_TAG, OBJECTIVE_TAG, HUMANOID_TAG })

		local blue = createTaggedHumanoidModel("BlueHumanoid", HUMANOID_TAG)
		blue:SetAttribute("TeamId", "Blue")
		blue:SetAttribute("Frequency", 2.5)

		local global = createTaggedHumanoidModel("GlobalHumanoid", HUMANOID_TAG)

		local invalid = Instance.new("Model")
		invalid.Name = "InvalidHumanoid"
		invalid.Parent = Workspace
		CollectionService:AddTag(invalid, HUMANOID_TAG)

		local registry = StudioWorldRegistry.new(createTestConfig(SPAWN_TAG))
		local blueModels = registry:GetHumanoidModels("Blue")
		local redModels = registry:GetHumanoidModels("Red")

		context.AssertEqual(#blueModels, 2, "Blue team should read team-specific and global humanoid models")
		context.AssertEqual(#redModels, 1, "Red team should only read global humanoid model")

		local blueRecord = blueModels[1]
		if blueRecord.model ~= blue then
			blueRecord = blueModels[2]
		end

		context.Assert(blueRecord.model == blue, "Blue humanoid model should be recorded")
		context.AssertEqual(blueRecord.teamId, "Blue", "humanoid model should read TeamId")
		context.AssertEqual(blueRecord.frequency, 2.5, "humanoid model should read Frequency")
		context.Assert(blueRecord.humanoid == blue:FindFirstChildOfClass("Humanoid"), "humanoid model should store Humanoid")
		context.Assert(blueRecord.rootPart == blue:FindFirstChild("HumanoidRootPart"), "humanoid model should store root part")
		context.AssertEqual(redModels[1].frequency, 1.0, "humanoid model without Frequency should default to 1.0")
		context.Assert(redModels[1].model == global, "global humanoid model should be returned for other teams")

		cleanupTaggedInstances({ SPAWN_TAG, COVER_TAG, OBJECTIVE_TAG, HUMANOID_TAG })
	end,
})

table.insert(StudioWorldRegistryTests, {
	name = "StudioWorldRegistry parses tagged cover and objective points",
	run = function(context: Types.TestContext): ()
		cleanupTaggedInstances({ SPAWN_TAG, COVER_TAG, OBJECTIVE_TAG, HUMANOID_TAG })

		local cover = createTaggedPart("CoverPart", COVER_TAG, CFrame.new(4, 0, 8))
		cover:SetAttribute("CoverId", "cover-a")
		cover:SetAttribute("CoverQuality", 0.75)
		cover:SetAttribute("TeamId", "Blue")
		cover:SetAttribute("FacingX", 0)
		cover:SetAttribute("FacingY", 0)
		cover:SetAttribute("FacingZ", -1)

		local objective = createTaggedPart("ObjectivePart", OBJECTIVE_TAG, CFrame.new(6, 0, 12))
		objective:SetAttribute("ObjectiveId", "objective-a")
		objective:SetAttribute("Radius", 18)

		local registry = StudioWorldRegistry.new(createTestConfig(SPAWN_TAG))
		local coverPoints = registry:GetCoverPoints("Blue")
		local objectives = registry:GetObjectives("Blue")

		context.AssertEqual(#coverPoints, 1, "Blue team should read tagged cover point")
		context.AssertEqual(coverPoints[1].coverId, "cover-a", "cover should read CoverId")
		context.AssertEqual(coverPoints[1].coverQuality, 0.75, "cover should read CoverQuality")
		context.Assert(coverPoints[1].facing == Vector3.new(0, 0, -1), "cover should read facing attributes")

		context.AssertEqual(#objectives, 1, "Blue team should read global objective point")
		context.AssertEqual(objectives[1].objectiveId, "objective-a", "objective should read ObjectiveId")
		context.AssertEqual(objectives[1].radius, 18, "objective should read Radius")
		context.Assert(objectives[1].position == objective.Position, "objective should record Position")

		cleanupTaggedInstances({ SPAWN_TAG, COVER_TAG, OBJECTIVE_TAG, HUMANOID_TAG })
	end,
})

table.insert(StudioWorldRegistryTests, {
	name = "Simulation falls back to config spawns when Studio spawns are absent",
	run = function(context: Types.TestContext): ()
		cleanupTaggedInstances({ EMPTY_SPAWN_TAG })

		local levelConfig: Types.LevelConfig = {
			UseStudioLevel = true,
			UseConfigSpawnsFallback = true,
			SpawnTag = EMPTY_SPAWN_TAG,
			CoverTag = COVER_TAG,
			ObjectiveTag = OBJECTIVE_TAG,
			HumanoidTag = HUMANOID_TAG,
		}

		withSimulationConfig(levelConfig, false, function(): ()
			local simulation = Simulation.new()

			simulation:_spawnDemoAgents(2)

			context.AssertEqual(#simulation.agentStore:GetTeam("Blue"), 2, "Blue team should fall back to config spawns")
			context.AssertEqual(#simulation.agentStore:GetTeam("Red"), 2, "Red team should fall back to config spawns")
		end)

		cleanupTaggedInstances({ EMPTY_SPAWN_TAG })
	end,
})

return StudioWorldRegistryTests
