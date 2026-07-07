--[=[
	SchedulerTests

	Tests fixed-cadence callbacks and queue processing order for the central
	scheduler.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)
local BudgetQueue = require(CompyServerScripts.Core.BudgetQueue)
local Scheduler = require(CompyServerScripts.Core.Scheduler)

local SchedulerTests: { Types.TestCase } = {}

local function createContext(dt: number, now: number): Types.SimulationContext
	return {
		dt = dt,
		now = now,
	}
end

table.insert(SchedulerTests, {
	name = "Scheduler runImmediately interval fires and queue processes in same step",
	run = function(context: Types.TestContext): ()
		local scheduler = Scheduler.new()
		local queue = BudgetQueue.new("Planning", {
			MaxJobsPerFrame = 4,
			MaxMsPerFrame = 100,
		})
		local callbackCount = 0
		local processedCount = 0

		scheduler:RegisterQueue("Planning", queue)
		scheduler:Every("enqueue-test", 0.5, function(stepContext: Types.SimulationContext): ()
			callbackCount = callbackCount + 1
			queue:Enqueue({
				id = "queued-from-callback-" .. tostring(callbackCount),
				run = function(jobContext: Types.SimulationContext): boolean
					if jobContext.now == stepContext.now then
						processedCount = processedCount + 1
					end
					return true
				end,
			})
		end, true)

		scheduler:Step(createContext(0.1, 0.1))

		context.AssertEqual(callbackCount, 1, "runImmediately interval should fire on first step")
		context.AssertEqual(processedCount, 1, "queue job enqueued by interval should process in same step")
	end,
})

table.insert(SchedulerTests, {
	name = "Scheduler accumulates interval time before firing",
	run = function(context: Types.TestContext): ()
		local scheduler = Scheduler.new()
		local callbackCount = 0

		scheduler:Every("cadence-test", 0.5, function(_stepContext: Types.SimulationContext): ()
			callbackCount = callbackCount + 1
		end, false)

		scheduler:Step(createContext(0.25, 0.25))
		context.AssertEqual(callbackCount, 0, "interval should not fire before enough time accumulates")

		scheduler:Step(createContext(0.25, 0.5))
		context.AssertEqual(callbackCount, 1, "interval should fire once after reaching cadence")

		scheduler:Step(createContext(0.10, 0.6))
		context.AssertEqual(callbackCount, 1, "interval should not fire again early")
	end,
})

table.insert(SchedulerTests, {
	name = "Scheduler processes registered queues in registration order",
	run = function(context: Types.TestContext): ()
		local scheduler = Scheduler.new()
		local firstQueue = BudgetQueue.new("First", {
			MaxJobsPerFrame = 1,
			MaxMsPerFrame = 100,
		})
		local secondQueue = BudgetQueue.new("Second", {
			MaxJobsPerFrame = 1,
			MaxMsPerFrame = 100,
		})
		local output: { string } = {}

		firstQueue:Enqueue({
			id = "first",
			run = function(_stepContext: Types.SimulationContext): boolean
				table.insert(output, "first")
				return true
			end,
		})

		secondQueue:Enqueue({
			id = "second",
			run = function(_stepContext: Types.SimulationContext): boolean
				table.insert(output, "second")
				return true
			end,
		})

		scheduler:RegisterQueue("First", firstQueue)
		scheduler:RegisterQueue("Second", secondQueue)
		scheduler:Step(createContext(0.1, 0.1))

		context.AssertEqual(output[1], "first", "first registered queue should process first")
		context.AssertEqual(output[2], "second", "second registered queue should process second")
	end,
})

return SchedulerTests
