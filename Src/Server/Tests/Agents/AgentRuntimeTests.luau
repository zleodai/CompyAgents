local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CompyServerScripts = ServerScriptService.CompyAgent
local CompySharedScripts = ReplicatedStorage.CompyAgent

local AgentRuntime = require(CompyServerScripts.Agents.AgentRuntime)
local AgentModelStore = require(CompyServerScripts.Agents.AgentModelStore)
local AgentState = require(CompyServerScripts.Agents.AgentState)
local BlackboardStore = require(CompyServerScripts.Blackboard.BlackboardStore)
local AgentService = require(CompyServerScripts.World.AgentService)
local EnvironmentService = require(CompyServerScripts.World.EnvironmentService)
local Config = require(CompySharedScripts.Config)
local Types = require(CompyServerScripts.Core.Types)

local AgentRuntimeTests: { Types.TestCase } = {}

table.insert(AgentRuntimeTests, {
	name = "AgentRuntime damage marks agent dead",
	run = function(context: Types.TestContext): ()
		local config = table.clone(Config)
		config.NoobPath = table.clone(Config.NoobPath)
		config.NoobPath.Enabled = false

		local state = AgentState.create("Blue_01", "Blue", Vector3.zero, Vector3.xAxis, config)
		local runtime = AgentRuntime.new({
			config = config,
			state = state,
			blackboard = BlackboardStore.new("Blue"),
			environment = EnvironmentService.new(config),
			agentService = AgentService.new(),
			modelStore = AgentModelStore.new(config),
		})

		runtime:TakeDamage(200, "Red_01")
		context.Assert(not state.alive, "agent should be dead")
		context.AssertEqual(state.debugGoal, "Dead", "debug goal should show dead")
	end,
})

return AgentRuntimeTests
