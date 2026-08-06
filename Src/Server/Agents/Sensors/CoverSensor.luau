--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CompySharedScripts = ReplicatedStorage.CompyAgent
local AgentConfig = require(CompySharedScripts.Config.AgentConfig)

local CompyServerScripts = ServerScriptService.CompyAgent
local Util = require(CompyServerScripts.Core.Util)
local Types = require(CompyServerScripts.Core.Types)
local EnvironmentService = require(CompyServerScripts.Services.EnvironmentService)

local CoverSensor = {}
CoverSensor.__index = CoverSensor

type CoverSensorData = {
	config: typeof(AgentConfig),
	agentSharedData: Types.AgentSharedData,
	debug: { [string]: TextLabel },
}

export type CoverSensor = typeof(setmetatable({} :: CoverSensorData, CoverSensor))

function CoverSensor.New(agentSharedData: Types.AgentSharedData, config: typeof(AgentConfig))
	return setmetatable({
		agentSharedData = agentSharedData,
		config = config,
		debug = {},
	}, CoverSensor)
end

CoverSensor.Blank = setmetatable({}, CoverSensor) :: CoverSensor

function CoverSensor.Sense(self: CoverSensor): ()
	local cframe = self.agentSharedData.head.CFrame
	local position = cframe.Position

	local sightedEnemyLocs = self.agentSharedData.sightedEnemyLocs
	if #sightedEnemyLocs == 0 then
		return
	end

	local sightedCoverLocs = {}

	local seenCoverSpots = EnvironmentService:QueryFreeCoverSpotsByDistance(position, self.config.CoverMaxDistance)
	for _, coverSpot in ipairs(seenCoverSpots) do
		local coverDir = coverSpot.position - position
		local agentCoverAngDiff = math.deg(coverDir:Angle(cframe.LookVector))
		if agentCoverAngDiff > self.config.VisionAngle then
			continue
		end

		local enemyDir = Vector3.zero
		for _, enemypart in sightedEnemyLocs do
			enemyDir += (enemypart.Position - coverSpot.position).Unit
		end
		enemyDir = Vector3.new(enemyDir.X, 0, enemyDir.Z)
		enemyDir = (enemyDir / #sightedEnemyLocs).Unit

		local coverSpotDir = coverSpot.facing

		local coverEnemyAngDiff = math.deg(math.acos(enemyDir:Dot(coverSpotDir)))
		if coverEnemyAngDiff > self.config.CoverMaxAngleDiff then
			continue
		end

		table.insert(sightedCoverLocs, coverSpot)
	end

	if self.agentSharedData.cover then
		table.insert(sightedCoverLocs, self.agentSharedData.cover)
	end

	self.agentSharedData.sightedCoverLocs = sightedCoverLocs
end

return CoverSensor
