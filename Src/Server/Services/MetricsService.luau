--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local CompyServerScripts = ServerScriptService.CompyAgent
local CompySharedScripts = ReplicatedStorage.CompyAgent

local AgentService = require(CompyServerScripts.Services.AgentService)
local _DefaultConfig = require(CompySharedScripts.Config)

local MetricsService = {}
MetricsService.__index = MetricsService

local FRAME_SAMPLE_LIMIT = 60

type MetricsServiceData = {
	config: typeof(_DefaultConfig),
	agentService: AgentService.AgentService,
	running: boolean,
	thread: thread?,
	heartbeatConnection: RBXScriptConnection?,
	frameSamples: { number },
	frameSampleIndex: number,
	frameSampleTotal: number,
	averageFrameMS: number,
	lastSample: { totalAgents: number, aliveAgents: number, sampledAt: number },
}

export type MetricsService = typeof(setmetatable({} :: MetricsServiceData, MetricsService))

function MetricsService.RecordFrame(self: MetricsService, deltaTime: number): ()
	local frameMS = deltaTime * 1000
	self.frameSampleIndex += 1
	if #self.frameSamples < FRAME_SAMPLE_LIMIT then
		table.insert(self.frameSamples, frameMS)
		self.frameSampleTotal += frameMS
	else
		local index = ((self.frameSampleIndex - 1) % FRAME_SAMPLE_LIMIT) + 1
		self.frameSampleTotal -= self.frameSamples[index]
		self.frameSamples[index] = frameMS
		self.frameSampleTotal += frameMS
	end
	self.averageFrameMS = self.frameSampleTotal / #self.frameSamples
end

function MetricsService.Sample(self: MetricsService): ()
	local alive = 0
	local records = self.agentService:GetAllRecords()
	for _, record in ipairs(records) do
		if not record.agent.active then
			alive += 1
		end
	end
	self.lastSample = {
		totalAgents = #records,
		aliveAgents = alive,
		sampledAt = os.clock(),
	}
end

function MetricsService.Start(self: MetricsService): ()
	if self.running then
		return
	end
	self.running = true
	self.heartbeatConnection = RunService.Heartbeat:Connect(function(dt: number): ()
		self:RecordFrame(dt)
	end)
	self.thread = task.spawn(function(): ()
		while self.running do
			self:Sample()
			task.wait(self.config.Simulation.MetricsInterval)
		end
	end)
end

function MetricsService.Stop(self: MetricsService): ()
	self.running = false
	self.thread = nil
	local connection = self.heartbeatConnection
	self.heartbeatConnection = nil
	if connection then
		connection:Disconnect()
	end
end

function MetricsService.GetAverageFrameMS(self: MetricsService): number
	return self.averageFrameMS
end

function MetricsService.new(config: typeof(_DefaultConfig), agentService: AgentService.AgentService): MetricsService
	return setmetatable({
		config = config,
		agentService = agentService,
		running = false,
		thread = nil,
		heartbeatConnection = nil,
		frameSamples = {},
		frameSampleIndex = 0,
		frameSampleTotal = 0,
		averageFrameMS = 0,
		lastSample = {
			totalAgents = 0,
			aliveAgents = 0,
			sampledAt = 0,
		},
	}, MetricsService)
end

return MetricsService
