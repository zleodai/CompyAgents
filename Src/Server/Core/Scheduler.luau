--[=[
	Scheduler

	Coordinates fixed-cadence system scans and per-frame queue processing for the
	simulation. Systems enqueue work here instead of each agent owning its own
	Heartbeat loop.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local Scheduler = {}
Scheduler.__index = Scheduler

function Scheduler:RegisterQueue(name: Types.QueueName, queue: Types.BudgetQueue): ()
	self.queues[name] = queue
	table.insert(self.queueOrder, name)
end

function Scheduler:GetQueue(name: Types.QueueName): Types.BudgetQueue?
	return self.queues[name]
end

function Scheduler:Every(
	name: string,
	intervalSeconds: number,
	callback: (Types.SimulationContext) -> (),
	runImmediately: boolean?
): ()
	self.intervals[name] = {
		interval = intervalSeconds,
		callback = callback,
		elapsed = runImmediately and intervalSeconds or 0,
	}
end

function Scheduler:Step(context: Types.SimulationContext): ()
	for _, timer in pairs(self.intervals) do
		timer.elapsed = timer.elapsed + context.dt

		if timer.elapsed >= timer.interval then
			timer.elapsed = timer.elapsed - timer.interval
			timer.callback(context)
		end
	end

	for _, queueName in ipairs(self.queueOrder) do
		self.queues[queueName]:Process(context)
	end
end

function Scheduler.new(): Types.Scheduler
	local self = setmetatable({}, Scheduler)

	self.queues = {}
	self.queueOrder = {}
	self.intervals = {}

	return self
end

return Scheduler
