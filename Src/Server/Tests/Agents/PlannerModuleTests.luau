--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local CompyServerScripts = ServerScriptService.CompyAgent

local PlannerModule = require(CompyServerScripts.Agents.Modules.PlannerModule)
local SPHAgentFactory = require(CompyServerScripts.Integrations.Spearhead.SPHAgentFactory)
local SPHController = require(CompyServerScripts.Integrations.Spearhead.SPHController)
local Types = require(CompyServerScripts.Core.Types)

type TestContext = {
	Assert: (condition: boolean, message: string) -> (),
}

local function createSharedData(requestReplan: (string) -> ()): Types.AgentSharedData
	return {
		teamId = "Blue",
		noisyEnemyDirection = Vector3.zero,
		noisyObjectiveDirection = Vector3.zero,
		sightedEnemyLocs = {},
		sightedObjectiveLocs = {},
		sightedCrouchCoverLocs = {},
		sightedProneCoverLocs = {},
		behaviourState = {
			behaviour = "None",
			behaviourParams = nil,
		},
		RequestChangeBehaviour = function(_request: Types.BehaviourState): () end,
		RequestReplan = requestReplan,
		RequestMagazine = function(): boolean
			return true
		end,
	}
end

local function withController(callback: (SPHController.SPHController) -> ()): ()
	local container = Instance.new("Folder")
	container.Name = "PlannerModuleTests"
	container.Parent = Workspace

	local controller: SPHController.SPHController? = nil
	local model: Model? = nil
	local succeeded, testError = xpcall(function(): ()
		local factory = SPHAgentFactory.new({
			teamId = "Blue",
			parent = container,
			maxHealth = 100,
		})
		controller = factory:Create("PlannerModuleTestAgent", CFrame.new(0, 1000, 0))
		model = controller:GetModel()
		callback(controller)
	end, debug.traceback)

	if controller then
		controller:Destroy()
	end
	if model and model.Parent then
		model:Destroy()
	end
	container:Destroy()

	if not succeeded then
		error(testError, 0)
	end
end

local PlannerModuleTests = {}

table.insert(PlannerModuleTests, {
	name = "PlannerModule executes and advances a successful plan without restarting it",
	run = function(context: TestContext): ()
		withController(function(controller: SPHController.SPHController): ()
			local planner = PlannerModule.new()
			planner:Awake(controller)

			local firstFinished = false
			local firstStarts = 0
			local firstUpdates = 0
			local firstEnds = 0
			local secondStarts = 0
			local secondUpdates = 0

			local firstAction: Types.Action = {
				id = "First",
				cost = 1,
				preconditions = { ready = true },
				effects = { middle = true },
				actionData = {},
				Start = function(): ()
					firstStarts += 1
				end,
				Update = function(): ()
					firstUpdates += 1
				end,
				FinishedCheck = function(): boolean
					return firstFinished
				end,
				End = function(): ()
					firstEnds += 1
				end,
			}
			local secondAction: Types.Action = {
				id = "Second",
				cost = 1,
				preconditions = { middle = true },
				effects = { done = true },
				actionData = {},
				Start = function(): ()
					secondStarts += 1
				end,
				Update = function(): ()
					secondUpdates += 1
				end,
				FinishedCheck = function(): boolean
					return false
				end,
				End = nil,
			}

			planner.actions = {
				First = firstAction,
				Second = secondAction,
			}
			planner.goals = {
				TestGoal = {
					id = "TestGoal",
					priority = 1,
					activation = { ready = true },
					desired = { done = true },
				},
			}

			local sharedData = createSharedData(function(reason: string): ()
				planner:Replan(reason)
			end)
			local beliefs = { ready = true }

			planner:Replan("initial plan")
			planner:Update(beliefs, sharedData, 0.1)
			context.Assert(planner.planSuccess, "a valid plan should be recorded as successful")
			context.Assert(not planner.needsReplan, "a valid plan should leave replan mode")
			context.Assert(planner.action == firstAction, "the first action should become authoritative")
			context.Assert(firstStarts == 1, "the first action should start exactly once")

			planner:Update(beliefs, sharedData, 0.1)
			context.Assert(firstUpdates == 1, "the next tick should update instead of restart the first action")
			context.Assert(firstStarts == 1, "updating should not start the first action again")

			firstFinished = true
			planner:Update(beliefs, sharedData, 0.1)
			context.Assert(firstEnds == 1, "a finished action should end exactly once")
			context.Assert(planner.action == secondAction, "the next action should become authoritative")
			context.Assert(secondStarts == 1, "the next action should start exactly once")

			planner:Update(beliefs, sharedData, 0.1)
			context.Assert(secondUpdates == 1, "the authoritative next action should receive updates")
			context.Assert(secondStarts == 1, "the next action should not restart while active")

			planner:ForceStop(sharedData)
		end)
	end,
})

table.insert(PlannerModuleTests, {
	name = "PlannerModule preserves Start replans and clears stale failed-plan state",
	run = function(context: TestContext): ()
		withController(function(controller: SPHController.SPHController): ()
			local planner = PlannerModule.new()
			planner:Awake(controller)

			local sharedData = createSharedData(function(reason: string): ()
				planner:Replan(reason)
			end)
			local action: Types.Action = {
				id = "RequestsReplan",
				cost = 1,
				preconditions = { ready = true },
				effects = { done = true },
				actionData = {},
				Start = function(_actionData, _controller, data: Types.AgentSharedData): ()
					data.RequestReplan("requested by Start")
				end,
				Update = nil,
				FinishedCheck = function(): boolean
					return false
				end,
				End = nil,
			}

			planner.actions = { RequestsReplan = action }
			planner.goals = {
				TestGoal = {
					id = "TestGoal",
					priority = 1,
					activation = { ready = true },
					desired = { done = true },
				},
			}

			planner:Replan("initial plan")
			planner:Update({ ready = true }, sharedData, 0.1)
			context.Assert(planner.planSuccess, "the installed plan should remain a successful result")
			context.Assert(planner.needsReplan, "Start should be able to request another plan synchronously")
			context.Assert(planner.replanReason == "requested by Start", "the Start replan reason should be retained")

			planner.goals = {}
			planner.lastFailedPlanAt = -math.huge
			planner:Update({ ready = true }, sharedData, 0.1)
			context.Assert(not planner.planSuccess, "a failed plan should clear the previous success state")
			context.Assert(planner.action == nil, "a failed plan should clear the stale action")
			context.Assert(planner.goal == nil, "a failed plan should clear the stale goal")
			context.Assert(#planner.plan == 0, "a failed plan should clear the stale plan")
			context.Assert(planner.planIndx == 0, "a failed plan should reset the plan index")

			planner:ForceStop(sharedData)
		end)
	end,
})

return PlannerModuleTests
