--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CompySharedScripts = ReplicatedStorage.CompyAgent
local AgentConfig = require(CompySharedScripts.Config.AgentConfig)

local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)

local BraveryModifier = {}
BraveryModifier.__index = BraveryModifier

type BraveryModifierData = {
	config: typeof(AgentConfig),
	agentSharedData: Types.AgentSharedData,
	rememberedHealth: number,
}

export type BraveryModifier = typeof(setmetatable({} :: BraveryModifierData, BraveryModifier))

function BraveryModifier.New(agentSharedData: Types.AgentSharedData, config: typeof(AgentConfig))
	return setmetatable({
		agentSharedData = agentSharedData,
		config = config,
		rememberedHealth = agentSharedData.health,
	}, BraveryModifier)
end

BraveryModifier.Blank = setmetatable({}, BraveryModifier) :: BraveryModifier

function BraveryModifier.Modify(self: BraveryModifier): ()
	local health = self.agentSharedData.health

	if self.rememberedHealth > health then
		self.agentSharedData.bravery = 0
	else
		self.agentSharedData.bravery += AgentConfig.BraveryIncreaseRate
	end

	self.rememberedHealth = health
end

return BraveryModifier
