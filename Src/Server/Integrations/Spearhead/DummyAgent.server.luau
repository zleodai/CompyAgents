--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CompyServerScripts = ServerScriptService.CompyAgent
local SPHController = require(CompyServerScripts.Integrations.Spearhead.SPHController)

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

configureWaypointCollider(waypointA)
configureWaypointCollider(waypointB)
configureWaypointCollider(waypointC)
configureWaypointCollider(waypointD)

local function getOrCreateDummy(name: string, spawnCFrame: CFrame): (Model, Humanoid)
	local existing = Workspace:FindFirstChild(name)
	local character: Model
	if existing and existing:IsA("Model") then
		character = existing
	else
		local description = Instance.new("HumanoidDescription")
		character = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
		description:Destroy()
		character.Name = name
		character.Parent = Workspace
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	assert(rootPart and rootPart:IsA("BasePart"), `{character:GetFullName()} is missing HumanoidRootPart`)
	character.PrimaryPart = rootPart
	character:PivotTo(spawnCFrame)

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			local canSetOwner = descendant:CanSetNetworkOwnership()
			if canSetOwner then
				descendant:SetNetworkOwner(nil)
			end
		end
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	assert(humanoid, `{character:GetFullName()} is missing a Humanoid`)
	humanoid.MaxHealth = 100
	humanoid.Health = humanoid.MaxHealth
	humanoid.DisplayName = name
	return character, humanoid
end

local dummyA, humanoidA =
	getOrCreateDummy("dummyA", CFrame.new(waypointA.Position + Vector3.new(0, 3, 0), waypointB.Position))
local dummyB, humanoidB =
	getOrCreateDummy("dummyB", CFrame.new(waypointC.Position + Vector3.new(0, 3, 0), waypointA.Position))

local controllerA = SPHController.new(dummyA, {
	weaponName = "AKM",
	moveTimeout = 30,
})
local controllerB = SPHController.new(dummyB, {
	weaponName = "AKM",
	moveTimeout = 30,
})

local headB = dummyB:FindFirstChild("Head") or dummyA:FindFirstChild("HumanoidRootPart")
if not headB or not headB:IsA("BasePart") then
	return
end
local headA = dummyA:FindFirstChild("Head") or dummyA:FindFirstChild("HumanoidRootPart")
if not headA or not headA:IsA("BasePart") then
	return
end

task.defer(function()
	local aDestination: BasePart = waypointB
	while humanoidA.Health > 0 do
		local reached = controllerA:MoveTo(aDestination, "Sprint")
		if not reached then
			return
		end

		aDestination = if aDestination == waypointA then waypointB else waypointA
	end
end)

task.defer(function()
	if not controllerB:Equip() then
		return
	end

	local aimCastParams = RaycastParams.new()
	aimCastParams.FilterDescendantsInstances = { dummyB }
	aimCastParams.FilterType = Enum.RaycastFilterType.Exclude

	while humanoidA.Health > 0 do
		local aimCast = Workspace:Raycast(headB.Position, headA.Position - headB.Position, aimCastParams)
		if not aimCast or aimCast.Instance ~= headA then
			task.wait(0.1)
			continue
		end

		controllerB:Aim(headA.Position)

		local ammo, _ = controllerB:GetAmmo()
		if ammo == 0 then
			controllerB:Reload()
			task.wait(0.1)
			continue
		end

		if controllerB:CanFire() then
			controllerB:Fire()
		end

		task.wait(0.1)
	end

	controllerB:Unequip()
	controllerB:MoveTo(waypointD, "CrouchWalk")
end)

local heartBeat = RunService.Heartbeat:Connect(function()
	if humanoidA.Health <= 0 then
		controllerA:Destroy()
	end

	if humanoidB.Health <= 0 then
		controllerB:Destroy()
	end
end)

game:BindToClose(function(): ()
	heartBeat:Disconnect()
end)
