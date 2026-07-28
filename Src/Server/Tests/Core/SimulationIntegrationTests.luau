--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local CompyServerScripts = ServerScriptService.CompyAgent
local CompySharedScripts = ReplicatedStorage.CompyAgent

local Config = require(CompySharedScripts.Config)
local Simulation = require(CompyServerScripts.Core.Simulation)

type TestContext = {
	Assert: (condition: boolean, message: string) -> (),
	AssertEqual: (actual: any, expected: any, message: string) -> (),
	AssertNear: (actual: number, expected: number, tolerance: number, message: string) -> (),
	AssertThrows: (callback: () -> (), message: string) -> (),
}

local TEST_TEAM = "IntegrationBlue"

local function createConfig(spawnTag: string, agentCount: number): any
	local config = table.clone(Config)
	config.Simulation = table.clone(Config.Simulation)
	config.Agent = table.clone(Config.Agent)
	config.Cadence = table.clone(Config.Cadence)
	config.Simulation.AgentService = table.clone(Config.Simulation.AgentService)
	config.Simulation.DemoAgentsPerTeam = agentCount
	config.Simulation.SpawnTag = spawnTag
	config.Simulation.CoverTag = `{spawnTag}_Cover`
	config.Simulation.ObjectiveTag = `{spawnTag}_Objective`
	config.Teams = {
		[TEST_TEAM] = {
			Color = Color3.new(0, 0, 1),
			SpawnOrigin = Vector3.new(800, 20, 800),
			SpawnSpacing = 12,
			Forward = Vector3.new(1, 0, 0),
		},
	}
	return config
end

local function createSpawn(tagName: string, name: string, position: Vector3, spawnOrder: number, spawnRadius: number): Part
	local spawn = Instance.new("Part")
	spawn.Name = name
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.CFrame = CFrame.lookAt(position, position + Vector3.new(0, 0, -1))
	spawn:SetAttribute("TeamId", TEST_TEAM)
	spawn:SetAttribute("SpawnOrder", spawnOrder)
	spawn:SetAttribute("SpawnRadius", spawnRadius)
	spawn.Parent = Workspace
	CollectionService:AddTag(spawn, tagName)
	return spawn
end

local function horizontalDistance(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

local SimulationIntegrationTests = {}

table.insert(SimulationIntegrationTests, {
	name = "Simulation owns service lifecycle, round-robin spawns, and monotonic IDs",
	run = function(context: TestContext): ()
		local tagName = "CompySimulationIntegrationRoundRobin"
		local firstSpawn = createSpawn(tagName, "First", Vector3.new(900, 20, 900), 1, 0)
		local secondSpawn = createSpawn(tagName, "Second", Vector3.new(940, 20, 900), 2, 0)
		local simulation = Simulation.new(createConfig(tagName, 2))

		local succeeded, testError = pcall(function(): ()
			simulation:Start()
			context.Assert(simulation.agentService.running, "AgentService should be running after Simulation.Start")
			context.Assert(simulation.environment.running, "EnvironmentService should be running after Simulation.Start")
			context.AssertEqual(#simulation.agents, 2, "the configured wave should be constructed")
			context.AssertEqual(simulation.agents[1].id, 1, "the first ID should be one")
			context.AssertEqual(simulation.agents[2].id, 2, "the second ID should be two")
			context.AssertEqual(simulation.agents[1].teamId, TEST_TEAM, "Simulation should assign the configured team to each Agent")
			context.AssertEqual(simulation.agents[1].controller:GetTeamId(), TEST_TEAM, "the factory should pass team assignment into SPHController")
			context.AssertEqual(simulation.agentService:GetAgent(1), simulation.agents[1], "Agents should register before runtime")
			context.AssertEqual(simulation.agentService:GetTeamId(1), TEST_TEAM, "AgentService should retain the registered team")
			context.AssertEqual(simulation.agents[1].vision.agentService, simulation.agentService, "VisionSensor should receive the Simulation-owned AgentService")
			context.AssertEqual(simulation.agents[1].vision.environmentService, simulation.environment, "VisionSensor should receive the Simulation-owned EnvironmentService")
			context.Assert(simulation.agents[1].active, "registered Agents should start their runtime")
			context.AssertNear(horizontalDistance(simulation.agents[1].controller:GetModel():GetPivot().Position, firstSpawn.Position), 0, 0.01, "first Agent should use the first spawn")
			context.AssertNear(horizontalDistance(simulation.agents[2].controller:GetModel():GetPivot().Position, secondSpawn.Position), 0, 0.01, "second Agent should use the second spawn")
			local deadAgent = simulation.agents[1]
			local humanoid = deadAgent.controller:GetHumanoid()
			humanoid.Health = 0
			local deathDeadline = os.clock() + 1
			while simulation.agentService:GetAgent(deadAgent.id) and os.clock() < deathDeadline do
				task.wait()
			end
			context.AssertEqual(simulation.agentService:GetAgent(deadAgent.id), nil, "Humanoid death should immediately remove AgentService lookups")

			simulation:SpawnAgents()
			context.AssertEqual(simulation.agents[3].id, 3, "a repeated wave should continue ID allocation")
			context.AssertEqual(simulation.agents[4].id, 4, "IDs should remain monotonic across repeated waves")
			context.Assert(simulation.agents[3].active, "Agents from repeated waves should start after registration")
			context.AssertNear(horizontalDistance(simulation.agents[3].controller:GetModel():GetPivot().Position, firstSpawn.Position), 0, 0.01, "round-robin selection should wrap to the first spawn")
			context.AssertNear(horizontalDistance(simulation.agents[4].controller:GetModel():GetPivot().Position, secondSpawn.Position), 0, 0.01, "round-robin selection should continue to the second spawn")

			local removedAgent = simulation.agents[4]
			local removedModel = removedAgent.controller:GetModel()
			context.Assert(simulation:RemoveAgent(removedAgent), "explicit removal should find the owned Agent")
			context.AssertEqual(simulation.agentService:GetAgent(4), nil, "explicit removal should unregister before teardown")
			context.AssertEqual(removedModel.Parent, nil, "explicit removal should destroy the Simulation-owned Model")
			context.Assert(not simulation:RemoveAgent(removedAgent), "repeated explicit removal should be safe")
		end)

		simulation:Stop()
		firstSpawn:Destroy()
		secondSpawn:Destroy()
		if not succeeded then
			error(testError, 0)
		end

		context.Assert(not simulation.agentService.running, "AgentService should stop before teardown completes")
		context.Assert(not simulation.environment.running, "EnvironmentService should end on Simulation.Stop")
		context.AssertEqual(#simulation.agents, 0, "Simulation.Stop should clear owned Agents")
	end,
})

table.insert(SimulationIntegrationTests, {
	name = "Simulation rolls back a partial repeated wave and retries cleanly",
	run = function(context: TestContext): ()
		local tagName = "CompySimulationIntegrationRollback"
		local spawn = createSpawn(tagName, "Rollback", Vector3.new(980, 20, 980), 1, 0)
		local config = createConfig(tagName, 1)
		local simulation = Simulation.new(config)
		local blocker = Instance.new("Model")
		blocker.Name = `{TEST_TEAM}_03`

		local succeeded, testError = pcall(function(): ()
			simulation:Start()
			local originalAgent = simulation.agents[1]
			config.Simulation.DemoAgentsPerTeam = 2
			blocker.Parent = Workspace

			local repeatedWaveSucceeded = pcall(function(): ()
				simulation:SpawnAgents()
			end)
			context.Assert(not repeatedWaveSucceeded, "the duplicate later name should fail the repeated wave")
			context.AssertEqual(#simulation.agents, 1, "a failed repeated wave should remove every Agent created by that invocation")
			context.AssertEqual(simulation.agents[1], originalAgent, "rollback should preserve the pre-existing Agent array")
			context.Assert(originalAgent.active, "rollback should leave pre-existing Agent runtime state untouched")
			context.AssertEqual(simulation.agentService:GetAgent(2), nil, "rollback should unregister the earlier partial-wave Agent")
			context.AssertEqual(simulation.spawnedAgentCountByTeam[TEST_TEAM], 1, "rollback should restore the team spawn counter")
			context.AssertEqual(simulation.nextAgentId, 3, "rollback should not reuse the consumed Agent ID")
			context.AssertEqual(Workspace:FindFirstChild(`{TEST_TEAM}_02`), nil, "rollback should destroy the partial-wave Model")

			blocker:Destroy()
			config.Simulation.DemoAgentsPerTeam = 1
			simulation:SpawnAgents()
			local retriedAgent = simulation.agents[2]
			context.AssertEqual(retriedAgent.id, 3, "the clean retry should continue monotonic ID allocation")
			context.AssertEqual(retriedAgent.controller:GetModel().Name, `{TEST_TEAM}_02`, "the clean retry should reuse the rolled-back spawn ordinal")
			context.Assert(retriedAgent.active, "the clean retry should start after registration")
			context.AssertEqual(simulation.agentService:GetAgent(3), retriedAgent, "the clean retry should be registered")
		end)

		simulation:Stop()
		spawn:Destroy()
		if blocker.Parent then
			blocker:Destroy()
		end
		if not succeeded then
			error(testError, 0)
		end
	end,
})

table.insert(SimulationIntegrationTests, {
	name = "Simulation samples spawn radius in a horizontal disc and preserves height",
	run = function(context: TestContext): ()
		local tagName = "CompySimulationIntegrationRadius"
		local spawn = createSpawn(tagName, "Radius", Vector3.new(1000, 30, 1000), 1, 8)
		local simulation = Simulation.new(createConfig(tagName, 4))

		local succeeded, testError = pcall(function(): ()
			simulation:Start()
			for _, agent in ipairs(simulation.agents) do
				local pivot = agent.controller:GetModel():GetPivot()
				local position = pivot.Position
				context.Assert(horizontalDistance(position, spawn.Position) <= 8.001, "sample must stay inside SpawnRadius")
				context.AssertNear(position.Y, spawn.Position.Y, 0.01, "spawn sampling must preserve Y")
				context.Assert(pivot.LookVector:Dot(spawn.CFrame.LookVector) >= 0.999, "spawn sampling must preserve facing")
			end
		end)

		simulation:Stop()
		spawn:Destroy()
		if not succeeded then
			error(testError, 0)
		end
	end,
})

table.insert(SimulationIntegrationTests, {
	name = "Simulation preserves config fallback and rolls back disabled fallback failure",
	run = function(context: TestContext): ()
		local fallbackConfig = createConfig("CompySimulationIntegrationNoSpawns", 2)
		fallbackConfig.Simulation.UseStudioLevel = false
		local fallbackSimulation = Simulation.new(fallbackConfig)
		fallbackSimulation:Start()
		context.AssertNear(horizontalDistance(fallbackSimulation.agents[1].controller:GetModel():GetPivot().Position, fallbackConfig.Teams[TEST_TEAM].SpawnOrigin), 0, 0.01, "first fallback spawn should use SpawnOrigin")
		context.AssertNear(horizontalDistance(fallbackSimulation.agents[2].controller:GetModel():GetPivot().Position, fallbackConfig.Teams[TEST_TEAM].SpawnOrigin + Vector3.new(0, 0, 12)), 0, 0.01, "fallback spawns should preserve spacing")
		fallbackSimulation:Stop()

		local disabledConfig = createConfig("CompySimulationIntegrationDisabled", 1)
		disabledConfig.Simulation.UseStudioLevel = false
		disabledConfig.Simulation.UseConfigSpawnsFallback = false
		local disabledSimulation = Simulation.new(disabledConfig)
		context.AssertThrows(function(): ()
			disabledSimulation:Start()
		end, "missing Studio spawns should fail when fallback is disabled")
		context.Assert(not disabledSimulation.started, "failed startup should restore stopped state")
		context.Assert(not disabledSimulation.agentService.running, "failed startup should end AgentService")
		context.Assert(not disabledSimulation.environment.running, "failed startup should end EnvironmentService")
		context.AssertEqual(#disabledSimulation.agents, 0, "failed startup should roll back constructed Agents")
	end,
})

return SimulationIntegrationTests
