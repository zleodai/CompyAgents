--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local SPHController = require(CompyServerScripts.Integrations.Spearhead.SPHController)
local Types = require(CompyServerScripts.Core.Types)
local CompySharedScripts = ReplicatedStorage.CompyAgent
local AgentConfig = require(CompySharedScripts.Config.AgentConfig)

local config: typeof(AgentConfig.FindEnemyLocation) = AgentConfig.FindEnemyLocation

local function GetMostRecentShot(heardShots: { [Vector3]: number }): Vector3?
	local choosenShot = nil
	local choosenShotTime = -math.huge -- not actual when the shot was fired but relatively it means that compared to other shotTimes

	for shotPos, shotTime in heardShots do
		if shotTime > choosenShotTime then
			choosenShot = shotPos
			choosenShotTime = shotTime
		end
	end

	if not choosenShot then
		return nil
	end

	return choosenShot
end

local function RandomNoisyVector(): Vector3
	local rad = math.random(0, 2 * math.pi)
	local dist = math.random(-AgentConfig.SoundNoise, AgentConfig.SoundNoise)
	return Vector3.new(math.cos(rad), 0, math.sin(rad)).Unit * dist
end

local function MoveToTarget(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData): ()
	if not actionData.target then
		actionData.target = GetMostRecentShot(data.heardFireSounds)
	end

	if actionData.moveTask and coroutine.status(actionData.moveTask) ~= "dead" then
		controller:StopMoving()
	end

	actionData.moveTask = task.defer(function()
		local noisyTarget = actionData.target + RandomNoisyVector()
		controller:MoveTo(noisyTarget, "Sprint")
	end)

	task.defer(function()
		controller:ClearAim()
	end)

	if actionData.faceTask and coroutine.status(actionData.faceTask) ~= "dead" then
		controller:ClearAim()
	end
end

local function MoveToHeardShot(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData): ()
	local mostRecentShot = GetMostRecentShot(data.heardFireSounds)

	if not mostRecentShot then
		return
	end

	actionData.target = mostRecentShot
	MoveToTarget(actionData, controller, data)
end

local function Start(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData): ()
	actionData.started = false
	task.defer(function()
		controller
			:Equip()
			:andThen(function(equipped: boolean): ()
				if not equipped then
					return false
				end

				actionData.started = true
				MoveToHeardShot(actionData, controller, data)
			end)
			:catch(function(reason: any): ()
				warn(reason)
			end)
	end)
end

local function Update(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData, _dt: number): ()
	if not actionData.started then
		return
	end

	local resetPathfinding = false

	resetPathfinding = resetPathfinding or (not actionData.moveTask or (actionData.moveTask and coroutine.status(actionData.moveTask) == "dead"))

	if not resetPathfinding then
		local pos = data.head.Position
		local mostRecentShot = GetMostRecentShot(data.heardFireSounds)

		if mostRecentShot and actionData.target then
			local targetDir = (actionData.target - pos).Unit
			local recentShotDir = (mostRecentShot - pos).Unit

			local angDiff = math.deg(math.acos(targetDir:Dot(recentShotDir)))

			if angDiff > AgentConfig.InvestigateEnemyFiring.MaxSoundAngleDiff then
				actionData.target = mostRecentShot
				resetPathfinding = true
			end
		else
			actionData.target = mostRecentShot
			resetPathfinding = true
		end
	end

	if resetPathfinding then
		MoveToTarget(actionData, controller, data)
	end
end

local function FinishedCheck(_actionData: { [any]: any }, _controller: SPHController.SPHController, data: Types.AgentSharedData): boolean
	return #data.sightedEnemyLocs > 0 or next(data.heardFireSounds) == nil
end

local function End(actionData: { [any]: any }, controller: SPHController.SPHController, _data: Types.AgentSharedData): ()
	if actionData.moveTask and coroutine.status(actionData.moveTask) ~= "dead" then
		controller:StopMoving()
	end
	table.remove(actionData)
end

local Action = {}

function Action.new(): Types.Action
	return {
		id = "InvestigateEnemyFiring",
		cost = 1,
		preconditions = {
			heardEnemyFiring = true,
			inCover = false,
		},
		effects = {
			knowsEnemyPos = true,
			hasEnemyPos = true,
		},
		actionData = {},
		Start = Start,
		Update = Update,
		FinishedCheck = FinishedCheck,
		End = End,
	}
end

return Action
