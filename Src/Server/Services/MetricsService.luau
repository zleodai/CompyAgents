local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Types = require(CompyServerScripts.Core.Types)

local FRAME_SAMPLE_LIMIT = 60

local MetricsService = {}
MetricsService.__index = MetricsService

function MetricsService:_recordFrame(deltaTime: number): ()
	local frameMS = deltaTime * 1000
	self.frameSampleIndex += 1

	if #self.frameSamples < FRAME_SAMPLE_LIMIT then
		table.insert(self.frameSamples, frameMS)
		self.frameSampleTotal += frameMS
	else
		local sampleIndex = ((self.frameSampleIndex - 1) % FRAME_SAMPLE_LIMIT) + 1
		self.frameSampleTotal -= self.frameSamples[sampleIndex]
		self.frameSamples[sampleIndex] = frameMS
		self.frameSampleTotal += frameMS
	end

	if #self.frameSamples > 0 then
		self.averageFrameMS = self.frameSampleTotal / #self.frameSamples
	end
end

function MetricsService:_sample(): ()
	local alive = 0
	local total = 0

	for _, runtime in ipairs(self.agentService:GetAllRuntimes()) do
		total += 1
		if runtime.state.alive then
			alive += 1
		end
	end

	self.lastSample = {
		totalAgents = total,
		aliveAgents = alive,
		sampledAt = os.clock(),
	}
end

function MetricsService:Start(): ()
	if self.running then
		return
	end

	self.running = true
	self.heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime: number): ()
		self:_recordFrame(deltaTime)
	end)

	self.thread = task.spawn(function(): ()
		while self.running do
			self:_sample()
			task.wait(self.config.Simulation.MetricsInterval)
		end
	end)
end

function MetricsService:Stop(): ()
	self.running = false

	if self.heartbeatConnection then
		self.heartbeatConnection:Disconnect()
		self.heartbeatConnection = nil
	end
end

function MetricsService:GetAverageFrameMS(): number
	return self.averageFrameMS
end

function MetricsService.new(config: Types.Config, agentService: Types.AgentService): Types.MetricsService
	local self = setmetatable({}, MetricsService)
	self.config = config
	self.agentService = agentService
	self.running = false
	self.thread = nil
	self.heartbeatConnection = nil
	self.frameSamples = {}
	self.frameSampleIndex = 0
	self.frameSampleTotal = 0
	self.averageFrameMS = 0
	self.lastSample = {
		totalAgents = 0,
		aliveAgents = 0,
		sampledAt = 0,
	}
	return self
end

return MetricsService
