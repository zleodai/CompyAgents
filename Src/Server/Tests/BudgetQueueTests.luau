--[=[
	BudgetQueueTests

	Focused tests for the bounded queue used to spread expensive agent work
	across frames.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)
local BudgetQueue = require(CompyServerScripts.Core.BudgetQueue)

local BudgetQueueTests: { Types.TestCase } = {}

local function createContext(now: number): Types.SimulationContext
	return {
		dt = 1 / 60,
		now = now,
	}
end

local function createRecordingJob(id: string, priority: number, output: { string }): Types.QueueJob
	return {
		id = id,
		priority = priority,
		run = function(_context: Types.SimulationContext): boolean
			table.insert(output, id)
			return true
		end,
	}
end

table.insert(BudgetQueueTests, {
	name = "BudgetQueue processes highest priority jobs within frame job limit",
	run = function(context: Types.TestContext): ()
		local output: { string } = {}
		local queue = BudgetQueue.new("TestQueue", {
			MaxJobsPerFrame = 2,
			MaxMsPerFrame = 100,
		})

		context.Assert(queue:Enqueue(createRecordingJob("low", 1, output)), "low priority job should enqueue")
		context.Assert(queue:Enqueue(createRecordingJob("high", 30, output)), "high priority job should enqueue")
		context.Assert(queue:Enqueue(createRecordingJob("mid", 10, output)), "mid priority job should enqueue")

		local stats = queue:Process(createContext(1))

		context.AssertEqual(stats.lastProcessed, 2, "queue should respect MaxJobsPerFrame")
		context.AssertEqual(stats.lastCompleted, 2, "queue should complete two jobs")
		context.AssertEqual(stats.lastRemaining, 1, "queue should leave one job for a later frame")
		context.AssertEqual(output[1], "high", "highest priority job should run first")
		context.AssertEqual(output[2], "mid", "second highest priority job should run second")
	end,
})

table.insert(BudgetQueueTests, {
	name = "BudgetQueue rejects duplicate ids while queued and releases id after processing",
	run = function(context: Types.TestContext): ()
		local output: { string } = {}
		local queue = BudgetQueue.new("TestQueue", {
			MaxJobsPerFrame = 1,
			MaxMsPerFrame = 100,
		})

		context.Assert(queue:Enqueue(createRecordingJob("same-id", 1, output)), "first job should enqueue")
		context.Assert(not queue:Enqueue(createRecordingJob("same-id", 2, output)), "duplicate queued id should reject")

		queue:Process(createContext(1))

		context.Assert(queue:Enqueue(createRecordingJob("same-id", 1, output)), "processed id should be reusable")
		context.AssertEqual(queue:Length(), 1, "reused id should add exactly one queued job")
	end,
})

table.insert(BudgetQueueTests, {
	name = "BudgetQueue requeues jobs that return false",
	run = function(context: Types.TestContext): ()
		local attempts = 0
		local queue = BudgetQueue.new("TestQueue", {
			MaxJobsPerFrame = 1,
			MaxMsPerFrame = 100,
		})

		queue:Enqueue({
			id = "retry",
			priority = 1,
			run = function(_jobContext: Types.SimulationContext): boolean
				attempts = attempts + 1
				return attempts >= 2
			end,
		})

		local firstStats = queue:Process(createContext(1))
		context.AssertEqual(firstStats.lastCompleted, 0, "first retry attempt should not complete")
		context.AssertEqual(firstStats.lastRemaining, 1, "failed retry should remain queued")

		local secondStats = queue:Process(createContext(2))
		context.AssertEqual(secondStats.lastCompleted, 1, "second retry attempt should complete")
		context.AssertEqual(secondStats.lastRemaining, 0, "completed retry should leave the queue")
		context.AssertEqual(attempts, 2, "retry job should run exactly twice")
	end,
})

return BudgetQueueTests
