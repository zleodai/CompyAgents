--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local CompySharedScripts = ReplicatedStorage.CompyAgent
local SPHController = require(CompyServerScripts.Integrations.Spearhead.SPHController)
local Types = require(CompyServerScripts.Core.Types)
local AgentConfig = require(CompySharedScripts.Config.AgentConfig)

local config: typeof(AgentConfig.EngageEnemy) = AgentConfig.EngageEnemy

local function aimAndShoot(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData): ()
	local target = actionData.target
	if not target or target.Parent == nil then
		data.RequestReplan(" [ EngageEnemy aimAndShoot ] target head is no longer available")
		return
	end

	controller
		:Aim(target.Position)
		:andThen(function(_: boolean): any
			return controller:Fire()
		end)
		:andThen(function(_: boolean): ()
			actionData.canFire = true
		end)
		:catch(function(reason): ()
			warn("Aim/fire failed:", reason)
		end)
end

local function findClosestTarget(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData): (boolean, string)
	if #data.sightedEnemyLocs == 0 then
		return false, "#data.sightedEnemyLocs == 0"
	end

	actionData.target = nil
	actionData.targetDist = nil
	local pos = controller:GetHeadPart().Position
	for _, head in data.sightedEnemyLocs do
		if head.Parent == nil then
			continue
		end
		local distance = (pos - head.Position).Magnitude

		if not actionData.target or not actionData.targetDist then
			actionData.target = head
			actionData.targetDist = distance
			continue
		end

		if distance < actionData.targetDist then
			actionData.target = head
			actionData.targetDist = distance
		end
	end

	if not actionData.target then
		return false, "actionData.target not found"
	end

	actionData.detectionStep = os.clock() + config.DetectionInterval
	return true, "None"
end

local function moveToClosestTarget(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData): boolean
	local target = actionData.target
	if not target or target.Parent == nil then
		data.RequestReplan(" [ EngageEnemy moveToClosestTarget ] target head is no longer available")
		return false
	end
	actionData.moveTask = task.defer(function()
		controller:MoveTo(target.Position, "Walk")
	end)

	actionData.retargetStep = os.clock() + config.RetargetInterval
	return false
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

				task.wait(math.random(config.StartFiringDelayMin, config.StartFiringDelayMax))

				local success, err = findClosestTarget(actionData, controller, data)
				if not success then
					data.RequestReplan(" [ EngageEnemy findClosestTarget ] no enemies sighted, Error: " .. err)
					return false
				end

				moveToClosestTarget(actionData, controller, data)

				actionData.started = true
				actionData.canFire = true
				actionData.engangementEndTime = os.clock() + config.MaxEngagingTime
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

	if actionData.detectionStep and os.clock() > actionData.detectionStep then
		if not findClosestTarget(actionData, controller, data) then
			data.RequestReplan(" [ EngageEnemy findClosestTarget ] no enemies sighted")
			return false
		end

		if actionData.targetDist < config.EngagementDistance then
			task.defer(function()
				controller:StopMoving()
			end)
		else
			if actionData.retargetStep and os.clock() > actionData.retargetStep then
				moveToClosestTarget(actionData, controller, data)
			end
		end
	end

	if actionData.canFire and actionData.targetDist < config.FiringDistance then
		actionData.canFire = false
		actionData.shootTask = task.defer(function()
			aimAndShoot(actionData, controller, data)
		end)
	end
end

local function FinishedCheck(actionData: { [any]: any }, controller: SPHController.SPHController, _: Types.AgentSharedData): boolean
	if not actionData.started then
		return false
	end

	local ammo, _ = controller:GetAmmo()
	local noAmmo = ammo == 0

	local maxEnagementTimeReached = os.clock() > actionData.engangementEndTime

	return noAmmo or maxEnagementTimeReached
end

local function End(actionData: { [any]: any }, controller: SPHController.SPHController, _: Types.AgentSharedData): ()
	if actionData.moveTask and coroutine.status(actionData.moveTask) ~= "dead" then
		controller:StopMoving()
	end
	table.clear(actionData)
end

local Action = {}

function Action.new(): Types.Action
	return {
		id = "EngageEnemy",
		cost = 2,
		preconditions = {
			hasEnemyPos = true,
			hasAmmo = true,
			inCover = false,
		},
		effects = {
			enemyEngaged = true,
		},
		actionData = {},
		Start = Start,
		Update = Update,
		FinishedCheck = FinishedCheck,
		End = End,
	}
end

return Action
