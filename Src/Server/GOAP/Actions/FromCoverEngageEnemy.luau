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

local function Start(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData): ()
	actionData.started = false
	task.defer(function()
		controller
			:Equip()
			:andThen(function(_: boolean): any
				return controller:SetStance("Standing")
			end)
			:andThen(function(_: boolean): ()
				task.wait(math.random(config.StartFiringDelayMin, config.StartFiringDelayMax))

				local success, err = findClosestTarget(actionData, controller, data)
				if not success then
					data.RequestReplan(" [ FromCoverEngageEnemy findClosestTarget ] no enemies sighted, Error: " .. err)
					return false
				end

				actionData.started = true
				actionData.canFire = true
			end)
			:catch(function(reason): ()
				warn("FromCoverEngageEnemy start failed:", reason)
			end)
	end)
end

local function Update(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData, _dt: number): ()
	if not actionData.started then
		return
	end

	if actionData.canFire and actionData.targetDist and actionData.targetDist < config.FiringDistance then
		actionData.canFire = false
		actionData.shootTask = task.defer(function()
			aimAndShoot(actionData, controller, data)
		end)
	end
end

local function FinishedCheck(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData): boolean
	if not actionData.started then
		return false
	end

	local ammo, _ = controller:GetAmmo()
	local noAmmo = ammo == 0

	return noAmmo
end

local function End(actionData: { [any]: any }, controller: SPHController.SPHController, data: Types.AgentSharedData): ()
	table.clear(actionData)
end

local Action = {}

function Action.new(): Types.Action
	return {
		id = "FromCoverEngageEnemy",
		cost = 0.5,
		preconditions = {
			brave = true,
			hasEnemyPos = true,
			hasAmmo = true,
			inCover = true,
			coverInvalid = false,
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
