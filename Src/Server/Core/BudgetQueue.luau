--[=[
	BudgetQueue

	Priority-aware bounded work queue used to keep expensive agent updates within
	per-frame budgets. If jobs exceed the frame budget, the delay is applied to
	agents waiting for work instead of creating a server spike.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local BudgetQueue = {}
BudgetQueue.__index = BudgetQueue

function BudgetQueue:Enqueue(job: Types.QueueJob): boolean
	if job.id and self.inQueue[job.id] then
		return false
	end

	job.priority = job.priority or 0
	table.insert(self.items, job)

	if job.id then
		self.inQueue[job.id] = true
	end

	return true
end

function BudgetQueue:Length(): number
	return #self.items
end

function BudgetQueue:Process(context: Types.SimulationContext): Types.QueueStats
	local processed = 0
	local completed = 0
	local errors = 0
	local startedAt = os.clock()
	local maxSeconds = self.maxMsPerFrame / 1000

	if #self.items > 1 then
		table.sort(self.items, function(a: Types.QueueJob, b: Types.QueueJob): boolean
			return (a.priority or 0) > (b.priority or 0)
		end)
	end

	while processed < self.maxJobsPerFrame and #self.items > 0 do
		if os.clock() - startedAt >= maxSeconds then
			break
		end

		local job = table.remove(self.items, 1)
		if job.id then
			self.inQueue[job.id] = nil
		end

		local ok, result = pcall(job.run, context)
		processed = processed + 1

		if not ok then
			errors = errors + 1
			warn(("[CompyAgent:%s] Job failed: %s"):format(self.name, tostring(result)))
		elseif result == false then
			self:Enqueue(job)
		else
			completed = completed + 1
		end
	end

	self.stats.lastProcessed = processed
	self.stats.lastCompleted = completed
	self.stats.lastErrors = errors
	self.stats.lastRemaining = #self.items

	return self.stats
end

function BudgetQueue.new(name: string, options: Types.QueueOptions): Types.BudgetQueue
	local self = setmetatable({}, BudgetQueue)

	self.name = name
	self.items = {}
	self.inQueue = {}

	self.maxJobsPerFrame = options.MaxJobsPerFrame or 1
	self.maxMsPerFrame = options.MaxMsPerFrame or 1

	self.stats = {
		lastProcessed = 0,
		lastCompleted = 0,
		lastErrors = 0,
		lastRemaining = 0,
	}

	return self
end

return BudgetQueue
