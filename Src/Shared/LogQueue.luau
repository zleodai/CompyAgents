--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local config = require(ReplicatedStorage.CompyAgent.Config)
local MAX_LOGS = config.Simulation.DebugService.MaxLogs :: number

local LogQueue = {}
LogQueue.__index = LogQueue

type Node = {
	nextNode: Node?,
	value: string,
}

type LogQueueData = {
	root: Node?,
	tail: Node?,
	count: number,
}

export type LogQueue = typeof(setmetatable({} :: LogQueueData, LogQueue))

function LogQueue.new(): LogQueue
	return setmetatable({
		root = nil,
		tail = nil,
		count = 0,
	}, LogQueue)
end

function LogQueue.clear(self: LogQueue): ()
	self.root = nil
	self.tail = nil
	self.count = 0
end

function LogQueue.push(self: LogQueue, value: string): ()
	local newNode = {
		nextNode = nil,
		value = value,
	}
	self.count = self.count + 1

	if self.count == 1 then
		self.root = newNode
		self.tail = newNode
		return
	end

	if self.root == nil or self.tail == nil then
		print("LogQueue Clearing: Internal Error when getting root or tail")
		self:clear()
		return
	end

	if self.count > MAX_LOGS then
		if self.root.nextNode then
			self.root = self.root.nextNode
		else
			print("LogQueue Clearing: Internal Error when getting nextNode of root")
			self:clear()
			return
		end
	end
	self.tail.nextNode = newNode
	self.tail = newNode
end

function LogQueue.getContents(self: LogQueue): string
	local contents = ""
	local node = self.root
	while node do
		contents = contents .. node.value .. "\n"
		node = node.nextNode
	end
	return contents
end

return LogQueue
