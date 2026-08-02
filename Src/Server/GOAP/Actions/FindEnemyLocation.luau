--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local SPHController = require(CompyServerScripts.Integrations.Spearhead.SPHController)
local Types = require(CompyServerScripts.Core.Types)
local CompySharedScripts = ReplicatedStorage.CompyAgent
local AgentConfig = require(CompySharedScripts.Config.AgentConfig)

local config: typeof(AgentConfig.FindEnemyLocation) = AgentConfig.FindEnemyLocation

local function MoveToNoisyLoc(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData): ()
	local pos = controller:GetHeadPart().Position
	local dist = math.random(config.FowardDistanceMin, config.FowardDistanceMax)

	actionData.target = pos + data.noisyEnemyDirection.Unit * dist
	actionData.retargetStep = os.clock() + config.RetargetInterval

	if actionData.moveTask and coroutine.status(actionData.moveTask) ~= "dead" then
		controller:StopMoving()
	end

	actionData.moveTaskStuckCheck = os.clock() + AgentConfig.FindEnemyLocation.StuckCheckInterval
	actionData.moveTaskStartLoc = pos

	actionData.moveTask = task.defer(function()
		controller:MoveTo(actionData.target, "Walk")
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
				MoveToNoisyLoc(actionData, controller, data)
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

	local stuck = false

	if actionData.moveTaskStuckCheck and os.clock() > actionData.moveTaskStuckCheck then
		local startPos: Vector3 = actionData.moveTaskStartLoc
		local pos: Vector3 = controller:GetHeadPart().Position

		local distanceMoved = (pos - startPos).Magnitude
		actionData.distanceMoved = distanceMoved
		stuck = distanceMoved < AgentConfig.FindEnemyLocation.StuckDistance
		actionData.moveTaskStuckCheck = os.clock() + AgentConfig.FindEnemyLocation.StuckCheckInterval
		actionData.moveTaskStartLoc = pos
	end

	local notMoving = not actionData.moveTask or (actionData.moveTask and coroutine.status(actionData.moveTask) == "dead")
	local retargetInterval = actionData.retargetStep and os.clock() > actionData.retargetStep

	if stuck or notMoving or retargetInterval then
		MoveToNoisyLoc(actionData, controller, data)
	end
end

local function FinishedCheck(_actionData: { [any]: any }, _controller: SPHController.SPHController, data: Types.AgentSharedData): boolean
	return #data.sightedEnemyLocs > 0
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
		id = "FindEnemyLocation",
		cost = 1,
		preconditions = {},
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
