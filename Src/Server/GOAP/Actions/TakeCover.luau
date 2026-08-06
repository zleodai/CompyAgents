--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CompySharedScripts = ReplicatedStorage.CompyAgent
local CompyServerScripts = ServerScriptService.CompyAgent
local SPHController = require(CompyServerScripts.Integrations.Spearhead.SPHController)
local Types = require(CompyServerScripts.Core.Types)
local Util = require(CompyServerScripts.Core.Util)
local EnvironmentService = require(CompyServerScripts.Services.EnvironmentService)
local AgentConfig = require(CompySharedScripts.Config.AgentConfig)

local function Start(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData): ()
	actionData.started = true

	local agentName = controller:GetModel().Name
	local pos = data.head.Position

	local coverSpots = data.sightedCoverLocs

	local closestCover = nil
	local closestCoverSpotDist = math.huge

	for _, coverSpot: EnvironmentService.CoverSpotRecord in ipairs(coverSpots) do
		if EnvironmentService:IsCoverTaken(coverSpot.part) then
			continue
		end

		local dist = (coverSpot.part.Position - pos).Magnitude

		if dist < closestCoverSpotDist then
			closestCover = coverSpot
			closestCoverSpotDist = dist
		end
	end

	if not closestCover then
		data.RequestReplan(`Finding ClosestCoverSpot failed from {agentName}`)
		return
	end

	EnvironmentService:SetCoverTakenStatus(closestCover, agentName, true)
	data.cover = closestCover
	actionData.coverSpot = closestCover

	actionData.moveTask = task.defer(function()
		controller:MoveTo(closestCover.position, "Sprint")
	end)
end

local function Update(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData, _dt: number): ()
	if not actionData.started then
		return
	end

	local resetPathfinding = false

	resetPathfinding = resetPathfinding or (not actionData.moveTask or (actionData.moveTask and coroutine.status(actionData.moveTask) == "dead"))

	if resetPathfinding then
		actionData.moveTask = task.defer(function()
			controller:MoveTo(actionData.coverSpot.position, "Sprint")
		end)
	end
end

local function FinishedCheck(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData): boolean
	if not actionData.started or not data.cover then
		return false
	end

	local pos = data.head.Position
	local coverPos = data.cover.part.position

	local distToCover = (Util.RemoveYValue(pos) - Util.RemoveYValue(coverPos)).Magnitude
	data.inCover = distToCover < AgentConfig.TakeCover.ReachCoverXZDist

	return data.inCover
end

local function End(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData): ()
	if actionData.moveTask and coroutine.status(actionData.moveTask) ~= "dead" then
		controller:StopMoving()
	end

	table.clear(actionData)

	controller:SetStance("Crouching")
end

local Action = {}

function Action.new(): Types.Action
	return {
		id = "TakeCover",
		cost = 0.25,
		preconditions = {
			knowsEnemyPos = true,
			inCover = false,
			coverAvailable = true,
		},
		effects = {
			inCover = true,
			coverInvalid = false,
		},
		actionData = {},
		Start = Start,
		Update = Update,
		FinishedCheck = FinishedCheck,
		End = End,
	}
end

return Action
