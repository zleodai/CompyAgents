--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CompySharedScripts = ReplicatedStorage.CompyAgent
local AgentConfig = require(CompySharedScripts.Config.AgentConfig)

local CompyServerScripts = ServerScriptService.CompyAgent
local Util = require(CompyServerScripts.Core.Util)
local Types = require(CompyServerScripts.Core.Types)
local SoundService = require(CompyServerScripts.Services.SoundService)

local SoundSensor = {}
SoundSensor.__index = SoundSensor

type SoundSensorData = {
	config: typeof(AgentConfig),
	agentSharedData: Types.AgentSharedData,
}

export type SoundSensor = typeof(setmetatable({} :: SoundSensorData, SoundSensor))

function SoundSensor.New(agentSharedData: Types.AgentSharedData, config: typeof(AgentConfig))
	return setmetatable({
		agentSharedData = agentSharedData,
		config = config,
	}, SoundSensor)
end

SoundSensor.Blank = setmetatable({}, SoundSensor) :: SoundSensor

function SoundSensor.Sense(self: SoundSensor): ()
	local pos = self.agentSharedData.head.Position
	local fireSounds = SoundService:GetEnemySounds(self.agentSharedData.teamId)
	local heardFireSounds = self.agentSharedData.heardFireSounds

	local toRemove = {}
	for soundPos, soundFadeTime in heardFireSounds do
		if os.clock() > soundFadeTime then
			table.insert(toRemove, soundPos)
			continue
		end

		if (pos - soundPos).Magnitude < self.config.SoundClearDistance then
			table.insert(toRemove, soundPos)
		end
	end
	for _, soundPos in toRemove do
		heardFireSounds[soundPos] = nil
	end

	for _, firePos: Vector3 in ipairs(fireSounds) do
		if heardFireSounds[firePos] then
			continue
		end

		local dist = (pos - firePos).Magnitude
		if dist < self.config.HearingDistance then
			heardFireSounds[firePos] = os.clock() + self.config.HearingFadeTime
		end
	end
end

return SoundSensor
