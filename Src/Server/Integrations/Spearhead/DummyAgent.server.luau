--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CompyServerScripts = ServerScriptService.CompyAgent
local CompySharedScripts = ReplicatedStorage.CompyAgent
local SPHController = require(script.Parent.SPHController)
local SPHAgentFactory = require(CompyServerScripts.Integrations.Spearhead.SPHAgentFactory)
local Promise = require(CompySharedScripts.Promise)

local function awaitAction(actionName: string, promise: Promise.Promise<boolean>): boolean
	local resolved, succeeded = promise:await()
	if not resolved then
		warn(`[SPHDamageTest] {actionName} Promise rejected: {succeeded}`)
		return false
	end
	if not succeeded then
		warn(`[SPHDamageTest] {actionName} resolved false`)
	end
	return succeeded
end

local function findWaypoint(name: string): BasePart?
	local folder = Workspace:FindFirstChild("Demo").Waypoints
	local candidate = if folder then folder:FindFirstChild(name) else Workspace:FindFirstChild(name)
	return if candidate and candidate:IsA("BasePart") then candidate else nil
end

local waypointA = findWaypoint("A")
local waypointB = findWaypoint("B")
local waypointC = findWaypoint("C")
local waypointD = findWaypoint("D")
if not waypointA or not waypointB or not waypointC or not waypointD then
	warn("[SPHDamageTest] Add BaseParts A, B, C, and D to Workspace or Workspace.SPHDummyWaypoints")
	return
end

local function configureWaypointCollider(waypoint: BasePart): ()
	waypoint.Anchored = true
	waypoint.CanCollide = true
	waypoint.CanTouch = true
	waypoint.CanQuery = true
	waypoint.Size =
		Vector3.new(math.max(waypoint.Size.X, 4), math.max(waypoint.Size.Y, 0.5), math.max(waypoint.Size.Z, 4))
	waypoint:SetAttribute("SPHArrivalCollider", true)
end

local function setupDeathDisconnect(contr: SPHController.SPHController)
	local humanoid = contr:GetHumanoid()

	local connection = RunService.Heartbeat:Connect(function()
		if humanoid.Health <= 0 then
			contr:Destroy()
		end
	end)

	game:BindToClose(function()
		connection:Disconnect()
	end)
end

local function setupPatrol(contr: SPHController.SPHController, a: BasePart, b: BasePart): ()
	local humanoid = contr:GetHumanoid()
	task.defer(function()
		local destination: BasePart = b
		while humanoid.Health > 0 do
			local reached = contr:MoveTo(destination, "Walk")
			if not reached then
				return
			end

			destination = if destination == a then b else a
		end
	end)
end

local function setupKillWatch(
	prefix: string,
	targetContrs: { SPHController.SPHController },
	a: BasePart,
	b: BasePart,
	agentFactory: SPHAgentFactory.SPHAgentFactory
): ()
	local guardController = agentFactory:Create(
		`guard{prefix}`,
		CFrame.new(a.Position + Vector3.new(0, 3, 0), b.Position),
		{ speedMult = 0.9 }
	)
	setupDeathDisconnect(guardController)

	task.defer(function()
		local guardHumanoid = guardController:GetHumanoid()
		local guardDummy = guardHumanoid.Parent or Instance.new("Part")
		local guardHead = guardController:GetHeadPart()

		local targetDummies = {}
		for indx, xContr in ipairs(targetContrs) do
			local humanoid = xContr:GetHumanoid()
			local targetDummy = humanoid.Parent
			targetDummies[indx] = targetDummy
		end

		while #targetContrs > 0 do
			local contrIndxToRemove = {}

			for indx, xContr in ipairs(targetContrs) do
				local humanoid = xContr:GetHumanoid()
				if humanoid.Health <= 0 then
					contrIndxToRemove[#contrIndxToRemove + 1] = indx
				end
			end

			for _, indx in ipairs(contrIndxToRemove) do
				table.remove(targetContrs, indx)
			end

			if #targetContrs == 0 then
				break
			end

			local targetContr: SPHController.SPHController
			local targetDist = math.huge

			for _, xContr in ipairs(targetContrs) do
				local head = xContr:GetHeadPart()
				local distance = (guardHead.Position - head.Position).Magnitude
				if distance < targetDist then
					targetDist = distance
					targetContr = xContr
				end
			end

			local targetHead = targetContr:GetHeadPart()

			guardController:Equip()
			if not awaitAction("Equip", guardController:Equip()) then
				return
			end

			local aimCastParams = RaycastParams.new()
			aimCastParams.FilterDescendantsInstances = { guardDummy }
			aimCastParams.FilterType = Enum.RaycastFilterType.Exclude

			local aimCast =
				Workspace:Raycast(guardHead.Position, targetHead.Position - guardHead.Position, aimCastParams)
			local hitCharacter = if aimCast then aimCast.Instance:FindFirstAncestorOfClass("Model") else nil
			if not table.find(targetDummies, hitCharacter) then
				task.wait(0.1)
				continue
			end

			local ammo, _ = guardController:GetAmmo()
			if ammo == 0 then
				guardController:Reload():await()
				continue
			end

			if not guardController:CanFire() then
				task.wait(0.1)
				continue
			end

			guardController
				:Aim(targetHead.Position)
				:andThen(function(aimed: boolean): any
					if not aimed then
						return false
					end

					return guardController:Fire()
				end)
				:catch(function(reason): ()
					warn("Aim/fire failed:", reason)
				end)
			task.wait(0.1)
		end

		guardController
			:ClearAim()
			:andThen(function(clearedAim: boolean): any
				if not clearedAim then
					return false
				end

				return guardController:Unequip()
			end)
			:andThen(function(unequipped: boolean): ()
				if not unequipped then
					return false
				end

				guardController:MoveTo(b, "CrouchWalk")
			end)
			:catch(function(reason): ()
				warn("ClearAim/Unequip/Moveto failed:", reason)
			end)
	end)
end

local function setupPatrolBots(
	prefix: string,
	amount: number,
	a: BasePart,
	b: BasePart,
	factory: SPHAgentFactory.SPHAgentFactory
): { SPHController.SPHController }
	local bots = {}

	for i = 1, amount do
		local contr =
			factory:Create(`PatrolAgent{prefix}{i}`, CFrame.new(a.Position + Vector3.new(0, 3, 0), b.Position))

		setupDeathDisconnect(contr)
		setupPatrol(contr, a, b)

		bots[i] = contr
	end

	return bots
end

configureWaypointCollider(waypointA)
configureWaypointCollider(waypointB)
configureWaypointCollider(waypointC)
configureWaypointCollider(waypointD)

local agentFactory = SPHAgentFactory.new({
	maxHealth = 80,
	controllerConfig = {
		weaponName = "AKM",
		moveTimeout = 30,
	},
})

local patrolBots = setupPatrolBots("A", 5, waypointA, waypointB, agentFactory)

setupKillWatch("A", patrolBots, waypointC, waypointD, agentFactory)
