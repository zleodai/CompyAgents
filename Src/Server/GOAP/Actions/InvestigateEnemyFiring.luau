--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local SPHController = require(CompyServerScripts.Integrations.Spearhead.SPHController)
local Types = require(CompyServerScripts.Core.Types)
local CompySharedScripts = ReplicatedStorage.CompyAgent
local AgentConfig = require(CompySharedScripts.Config.AgentConfig)

local config: typeof(AgentConfig.FindEnemyLocation) = AgentConfig.FindEnemyLocation

local function ChooseShot(heardShots: { [Vector3]: number }): Vector3?
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

local function MoveToHeardShot(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData): ()
	local pos = data.head.Position
	local closestHeardShot = ChooseShot(data.heardFireSounds)

	if not closestHeardShot then
		return
	end

	actionData.target = closestHeardShot
	actionData.retargetStep = os.clock() + config.RetargetInterval

	if actionData.moveTask and coroutine.status(actionData.moveTask) ~= "dead" then
		controller:StopMoving()
	end

	actionData.moveTaskStuckCheck = os.clock() + AgentConfig.FindEnemyLocation.StuckCheckInterval
	actionData.moveTaskStartLoc = pos

	actionData.moveTask = task.defer(function()
		local noisyTarget = actionData.target + RandomNoisyVector()
		controller:MoveTo(noisyTarget, "Walk")
	end)

	task.defer(function()
		controller:ClearAim()
	end)

	if actionData.faceTask and coroutine.status(actionData.faceTask) ~= "dead" then
		controller:ClearAim()
	end

	actionData.retargetStep = os.clock() + config.RetargetInterval
end

local function Start(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData): ()
	-- print(`{controller:GetHumanoid().Name} Finding Enemy Location`)

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

	if not resetPathfinding and (actionData.moveTaskStuckCheck and os.clock() > actionData.moveTaskStuckCheck) then
		local startPos: Vector3 = actionData.moveTaskStartLoc
		local pos: Vector3 = controller:GetHeadPart().Position

		local distanceMoved = (pos - startPos).Magnitude
		actionData.distanceMoved = distanceMoved
		resetPathfinding = distanceMoved < AgentConfig.FindEnemyLocation.StuckDistance
		actionData.moveTaskStuckCheck = os.clock() + AgentConfig.FindEnemyLocation.StuckCheckInterval
		actionData.moveTaskStartLoc = pos
	end

	resetPathfinding = resetPathfinding or (not actionData.moveTask or (actionData.moveTask and coroutine.status(actionData.moveTask) == "dead"))
	resetPathfinding = resetPathfinding or (actionData.retargetStep and os.clock() > actionData.retargetStep)

	if not resetPathfinding then
		local closestHeardShot = ChooseShot(data.heardFireSounds)

		if closestHeardShot then
			resetPathfinding = closestHeardShot ~= actionData.target
		end
	end

	if resetPathfinding then
		MoveToHeardShot(actionData, controller, data)
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
		},
		effects = {
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
