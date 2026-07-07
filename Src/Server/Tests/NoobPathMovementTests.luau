--[=[
	NoobPathMovementTests

	Verifies NoobPath package wiring and signal-to-AgentMovement state handling
	without asking Roblox pathfinding to compute a live route.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local CompyServerScripts = ServerScriptService.CompyAgent
local Config = require(CompyServerScripts.Core.Config)
local Types = require(CompyServerScripts.Core.Types)
local AgentState = require(CompyServerScripts.Agents.AgentState)
local AgentModelStore = require(CompyServerScripts.Agents.AgentModelStore)
local NoobPathMovement = require(CompyServerScripts.Adapters.Movement.NoobPathMovement)

local NoobPathMovementTests: { Types.TestCase } = {}

local MODEL_FOLDER = "CompyAgentNoobPathMovementModels"

local function createTestConfig(): Types.Config
	local config: Types.Config = table.clone(Config)
	config.AgentModel = table.clone(Config.AgentModel)
	config.NoobPath = table.clone(Config.NoobPath)
	config.NoobPath.AgentParams = table.clone(Config.NoobPath.AgentParams)
	config.NoobPath.AgentParams.Costs = table.clone(Config.NoobPath.AgentParams.Costs)
	config.NoobPath.AgentParams.PathSettings = table.clone(Config.NoobPath.AgentParams.PathSettings)
	config.AgentModel.FolderName = MODEL_FOLDER
	config.NoobPath.Timeout = true
	config.NoobPath.Visualize = false
	return config
end

local function cleanup(): ()
	local existing = Workspace:FindFirstChild(MODEL_FOLDER)
	if existing then
		existing:Destroy()
	end
end

table.insert(NoobPathMovementTests, {
	name = "NoobPathMovement can require ReplicatedStorage package",
	run = function(context: Types.TestContext): ()
		local noobPath = require(ReplicatedStorage.Packages.NoobPath)
		context.Assert(type(noobPath.Humanoid) == "function", "NoobPath package should expose Humanoid constructor")
	end,
})

table.insert(NoobPathMovementTests, {
	name = "NoobPathMovement creates humanoid path object with configured properties",
	run = function(context: Types.TestContext): ()
		cleanup()

		local config = createTestConfig()
		local store = AgentModelStore.new(config)
		local movement = NoobPathMovement.new(config, store)
		local agent = AgentState.create("Blue_NoobPath", "Blue", Vector3.new(0, 0, 0), Vector3.new(0, 0, 1))
		store:CreateForAgent(agent)

		local record = movement:_ensurePathAgent(agent)
		context.Assert(record ~= nil, "movement should create a NoobPath record")
		if record == nil then
			return
		end

		context.Assert(record.pathAgent.Timeout == config.NoobPath.Timeout, "path agent should use configured Timeout")
		context.Assert(record.pathAgent.Speed == config.Movement.Speed, "path agent should use Movement.Speed")
		context.Assert(record.pathAgent.Visualize == config.NoobPath.Visualize, "path agent should use configured Visualize")

		record.pathAgent:Destroy()
		store:DestroyAll()
		cleanup()
	end,
})

table.insert(NoobPathMovementTests, {
	name = "NoobPathMovement signals update AgentMovement state",
	run = function(context: Types.TestContext): ()
		cleanup()

		local config = createTestConfig()
		local store = AgentModelStore.new(config)
		local movement = NoobPathMovement.new(config, store)
		local agent = AgentState.create("Red_NoobPath", "Red", Vector3.new(0, 0, 0), Vector3.new(0, 0, 1))
		store:CreateForAgent(agent)

		local record = movement:_ensurePathAgent(agent)
		context.Assert(record ~= nil, "movement should create a NoobPath record")
		if record == nil then
			return
		end

		agent.movement.destination = Vector3.new(0, 0, 16)
		agent.movement.mode = "Moving"
		record.pathAgent.Reached:Fire(nil, false)
		task.wait()

		context.Assert(agent.movement.arrived, "Reached should mark movement arrived")
		context.Assert(agent.movement.destination == nil, "Reached should clear destination")
		context.AssertEqual(agent.movement.mode, "Idle", "Reached should return movement to Idle")

		agent.movement.destination = Vector3.new(0, 0, 20)
		agent.movement.needsPath = false
		agent.movement.pathQueued = true
		record.pathAgent.Trapped:Fire("ReachTimeout")
		task.wait()

		context.Assert(agent.movement.needsPath, "Trapped should request retry/repath")
		context.Assert(not agent.movement.pathQueued, "Trapped should clear path queued")

		agent.movement.destination = Vector3.new(0, 0, 24)
		agent.movement.pathQueued = true
		agent.decision.needsPlan = false
		record.pathAgent.Error:Fire("TargetUnreachable")
		task.wait()

		context.Assert(agent.decision.needsPlan, "Error should request a new plan")
		context.Assert(agent.movement.destination == nil, "Error should clear failed destination")
		context.Assert(not agent.movement.pathQueued, "Error should clear path queued")

		record.pathAgent:Destroy()
		store:DestroyAll()
		cleanup()
	end,
})

return NoobPathMovementTests
