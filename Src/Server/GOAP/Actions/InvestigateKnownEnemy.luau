--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local SPHController = require(CompyServerScripts.Integrations.Spearhead.SPHController)
local Types = require(CompyServerScripts.Core.Types)
local CompySharedScripts = ReplicatedStorage.CompyAgent
local AgentConfig = require(CompySharedScripts.Config.AgentConfig)

local config: typeof(AgentConfig.FindEnemyLocation) = AgentConfig.FindEnemyLocation

local function GetMostRecentEnemyPos(enemyLocs: { [Vector3]: number }): Vector3?
	local choosenLoc = nil
	local choosenLocTime = -math.huge

	for loc, time in enemyLocs do
		if time > choosenLocTime then
			choosenLoc = loc
			choosenLocTime = time
		end
	end

	if not choosenLoc then
		return nil
	end

	return choosenLoc
end

local function MoveToKnownEnemy(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData): ()
	local pos = data.head.Position
	local closestEnemyPos = GetMostRecentEnemyPos(data.rememberedEnemyLocs)

	if not closestEnemyPos then
		return
	end

	actionData.target = closestEnemyPos
	actionData.retargetStep = os.clock() + config.RetargetInterval

	if actionData.moveTask and coroutine.status(actionData.moveTask) ~= "dead" then
		controller:StopMoving()
	end

	actionData.moveTaskStuckCheck = os.clock() + AgentConfig.FindEnemyLocation.StuckCheckInterval
	actionData.moveTaskStartLoc = pos

	actionData.moveTask = task.defer(function()
		controller:MoveTo(actionData.target, "Sprint")
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
	actionData.started = false
	task.defer(function()
		controller
			:Equip()
			:andThen(function(equipped: boolean): ()
				if not equipped then
					return false
				end

				actionData.started = true
				MoveToKnownEnemy(actionData, controller, data)
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
		local closestHeardShot = GetMostRecentEnemyPos(data.rememberedEnemyLocs)

		if closestHeardShot then
			resetPathfinding = closestHeardShot ~= actionData.target
		end
	end

	if resetPathfinding then
		MoveToKnownEnemy(actionData, controller, data)
	end
end

local function FinishedCheck(_actionData: { [any]: any }, _controller: SPHController.SPHController, data: Types.AgentSharedData): boolean
	return #data.sightedEnemyLocs > 0 or next(data.rememberedEnemyLocs) == nil
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
		id = "InvestigateKnownEnemy",
		cost = 1.5,
		preconditions = {
			knowsEnemyPos = true,
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
