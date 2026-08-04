--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local CompySharedScripts = ReplicatedStorage.CompyAgent
local Config = require(CompySharedScripts.Config)

local CompyServerScripts = ServerScriptService.CompyAgent
local CompyEvents = CompyServerScripts.CompyEvents
local AgentFired = CompyEvents:WaitForChild("AgentFired") :: BindableEvent

type FireSound = {
	teamId: string,
	position: Vector3,
	startTime: number,
}

local SoundService = {}
SoundService.__index = SoundService

type SoundServiceData = {
	config: typeof(Config.Simulation.SoundService),
	fireSounds: { FireSound },
	updateConn: RBXScriptConnection?,
	agentFiredConn: RBXScriptConnection?,
}

export type SoundService = typeof(setmetatable({} :: SoundServiceData, SoundService))

function SoundService.Start(self: SoundService): ()
	self.updateConn = RunService.Heartbeat:Connect(function(_)
		self:Update()
	end)

	self.agentFiredConn = AgentFired.Event:Connect(function(teamId: string, position: Vector3)
		local newAgentFireSound = {
			teamId = teamId,
			position = position,
			startTime = os.clock(),
		} :: FireSound
		table.insert(self.fireSounds, newAgentFireSound)
		print(`Sound fired at {position}`)
	end)
end

function SoundService.Update(self: SoundService): ()
	local removeIndxs = {}
	for indx, agentFireSound in ipairs(self.fireSounds) do
		if os.clock() > agentFireSound.startTime + self.config.AgentFiredDuration then
			table.insert(removeIndxs, indx)
		end
	end

	for _, indx in ipairs(removeIndxs) do
		table.remove(self.fireSounds, indx)
	end
end

function SoundService.End(self: SoundService): ()
	if self.updateConn then
		self.updateConn:Disconnect()
	end

	if self.agentFiredConn then
		self.agentFiredConn:Disconnect()
	end

	table.clear(self.fireSounds)
end

function SoundService.GetEnemySounds(self: SoundService, teamId: any): { Vector3 }
	local team = teamId :: string
	local soundLocs = {} :: { Vector3 }

	for _, fireSound in self.fireSounds do
		if fireSound.teamId == team then
			continue
		end

		table.insert(soundLocs, fireSound.position)
	end
	return soundLocs
end

local singleton: SoundService = setmetatable({
	config = Config.Simulation.SoundService,
	fireSounds = {} :: { FireSound },
}, SoundService)

return singleton
