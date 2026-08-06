--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CompySharedScripts = ReplicatedStorage.CompyAgent
local AgentConfig = require(CompySharedScripts.Config.AgentConfig)

local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)
local EnvironmentService = require(CompyServerScripts.Services.EnvironmentService)

local MemoryModifier = {}
MemoryModifier.__index = MemoryModifier

type MemoryModifierData = {
	config: typeof(AgentConfig),
	agentSharedData: Types.AgentSharedData,
	agentService: any?,
}

export type MemoryModifier = typeof(setmetatable({} :: MemoryModifierData, MemoryModifier))

function MemoryModifier.New(agentSharedData: Types.AgentSharedData, config: typeof(AgentConfig), agentService: any)
	return setmetatable({
		agentSharedData = agentSharedData,
		config = config,
		agentService = agentService,
	}, MemoryModifier)
end

MemoryModifier.Blank = setmetatable({}, MemoryModifier) :: MemoryModifier

function MemoryModifier.Modify(self: MemoryModifier): ()
	local currentEnemies = self.agentSharedData.sightedEnemyLocs
	local rememberedEnemyLocs = self.agentSharedData.rememberedEnemyLocs

	local time = os.clock()

	local toRemove = {}

	for loc, memFadeTime in rememberedEnemyLocs do
		if time > memFadeTime then
			table.insert(toRemove, loc)
		end
	end

	for _, loc in ipairs(toRemove) do
		rememberedEnemyLocs[loc] = nil
	end

	table.clear(toRemove)

	for _, enemy in ipairs(currentEnemies) do
		local loc = enemy.Position
		for oldLoc, _ in rememberedEnemyLocs do
			if oldLoc == loc then
				continue
			end

			local dist = (loc - oldLoc).Magnitude
			if dist < self.config.MemoryMergeDist then
				table.insert(toRemove, oldLoc)
			end
		end

		rememberedEnemyLocs[loc] = time + self.config.MemoryFadeTime
	end

	for _, loc in ipairs(toRemove) do
		rememberedEnemyLocs[loc] = nil
	end
end

return MemoryModifier
