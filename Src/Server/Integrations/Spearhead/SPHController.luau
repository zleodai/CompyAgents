--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local CompyServerScripts = ServerScriptService.CompyAgent
local Enums = require(CompyServerScripts.Core.Enums)

local CompySharedScripts = ReplicatedStorage.CompyAgent
local NoobPath = require(ReplicatedStorage.Packages.NoobPath)
local Promise = require(CompySharedScripts.Promise)
local DefaultNoobPathConfig = require(CompySharedScripts.Config.NoobPathConfig)
local Team = require(CompySharedScripts.Team)

local CompyEvents = CompyServerScripts.CompyEvents
local AgentFired = CompyEvents:WaitForChild("AgentFired") :: BindableEvent

local SPHController = {}
SPHController.__index = SPHController

-- NPC-facing boundary for Spearhead assets. This controller intentionally does not
-- invoke Spearhead's Player remotes or install SPH_Character client scripts.

export type AnimationNames = {
	equip: string?,
	idle: string?,
	neutral: string?,
	aim: string?,
	fire: string?,
	reload: string?,
	chamber: string?,
	close: string?,
	switch: string?,
	sprint: string?,
	crouchIdle: string?,
	crouchMove: string?,
	proneIdle: string?,
	proneMove: string?,
	weaponProneMove: string?,
}

export type Config = {
	weaponName: string?,
	magazineCapacity: number?,
	reserveAmmo: number?,
	fireInterval: number?,
	reloadDuration: number?,
	range: number?,
	damage: number?,
	aimTime: number?,
	aimSpeed: number?,
	equipSpeedModifier: number?,
	walkSpeed: number?,
	sprintSpeed: number?,
	crouchSpeed: number?,
	proneSpeed: number?,
	speedMult: number?,
	reachDistance: number?,
	moveTimeout: number?,
	repathEnabled: boolean?,
	repathVelocityThreshold: number?,
	repathStuckDuration: number?,
	repathCooldown: number?,
	walkAnimationId: string?,
	crouchHipOffset: number?,
	proneHipOffset: number?,
	animationNames: AnimationNames?,
}

type NumericTable = { [string]: unknown }

type ControllerData = {
	teamId: Team.Id,
	character: Model,
	humanoid: Humanoid,
	model: Model,
	animator: Animator,
	rootPart: BasePart,
	aimAttachment: Attachment,
	aimOrientation: AlignOrientation,
	head: BasePart,
	torso: BasePart,
	neckJoint: Motor6D?,
	defaultNeckC1: CFrame?,
	headPoseConnection: RBXScriptConnection?,
	animations: Instance,
	weaponName: string,
	weapon: Tool?,
	weaponModel: Model?,
	weaponPartTransparencies: { [BasePart]: number },
	weaponGripMotor: Motor6D?,
	weaponAnimBase: BasePart,
	weaponBaseMotor: Motor6D,
	weaponRig: Model,
	weaponAnimator: Animator,
	weaponTracks: { [string]: AnimationTrack },
	inventory: Folder,
	holsterModel: Model?,
	holsterMotor: Motor6D?,
	holsterPosition: CFrame,
	animatedWeaponParts: { string },
	rightArm: BasePart,
	leftArm: BasePart,
	rightArmTransparency: number,
	leftArmTransparency: number,
	weaponServerOffset: CFrame,
	walkAnimation: Animation,
	magazineCapacity: number,
	reserveAmmo: number,
	ammo: number,
	fireInterval: number,
	reloadDuration: number,
	range: number,
	damage: number,
	aimTime: number,
	aimSpeed: number,
	equipSpeedModifier: number,
	walkSpeed: number,
	sprintSpeed: number,
	crouchSpeed: number,
	proneSpeed: number,
	speedMult: number,
	reachDistance: number,
	moveTimeout: number,
	repathEnabled: boolean,
	repathVelocityThreshold: number,
	repathStuckDuration: number,
	repathCooldown: number,
	pendingPathFailure: string?,
	terminalPathFailure: string?,
	pathRepathCount: number,
	defaultHipHeight: number,
	crouchHipOffset: number,
	proneHipOffset: number,
	animationOverrides: AnimationNames,
	animationNames: AnimationNames,
	tracks: { [string]: AnimationTrack },
	activeStanceTrack: AnimationTrack?,
	activeMovementTrack: AnimationTrack?,
	activeWeaponTrack: AnimationTrack?,
	weaponIdleTrack: AnimationTrack?,
	aimTarget: Vector3?,
	stance: Enums.Posture?,
	gait: Enums.Movement?,
	nextShotAt: number,
	reloading: boolean,
	equipped: boolean,
	destroyed: boolean,
	moveSerial: number,
	activeMoveSerial: number?,
	runPath: (Vector3) -> (),
	stopPath: () -> (),
	destroyPath: () -> (),
	setPathSpeed: (number) -> (),
}

export type SPHController = typeof(setmetatable({} :: ControllerData, SPHController))

local RIFLE_DEFAULT_ANIMATIONS: AnimationNames = {
	equip = "Rifle_Equip",
	idle = "Rifle_Idle",
	neutral = "Rifle_Neutral",
	aim = "Rifle_Aim",
	fire = nil,
	reload = "Rifle_Reload",
	chamber = "Rifle_Chamber",
	close = "Rifle_Close",
	switch = "Rifle_Switch",
	sprint = "Rifle_Sprint",
	crouchIdle = "Crouch_Idle",
	crouchMove = "Crouch_Move",
	proneIdle = "Prone_Idle",
	proneMove = "Prone_Move",
	weaponProneMove = "Rifle_Idle",
}

local DEFAULT_R6_WALK_ANIMATION = "rbxassetid://180426354"
local POSE_BLEND_TIME = 0.15

local function getMovementSpeed(self: SPHController, gait: Enums.Movement): number
	local speed: number
	if gait == "Sprint" then
		speed = self.sprintSpeed
	elseif gait == "CrouchWalk" then
		speed = self.crouchSpeed
	elseif gait == "ProneWalk" then
		speed = self.proneSpeed
	else
		assert(gait == "Walk", `Invalid gait {gait}`)
		speed = self.walkSpeed
	end
	return speed * self.speedMult
end

local function getGaitForStance(currentGait: Enums.Movement, stance: Enums.Posture): Enums.Movement
	if stance == "Crouching" then
		return "CrouchWalk"
	elseif stance == "Proning" then
		return "ProneWalk"
	elseif currentGait == "Sprint" then
		return "Sprint"
	end
	return "Walk"
end

local function mergeAnimationNames(overrides: AnimationNames?): AnimationNames
	local merged = table.clone(RIFLE_DEFAULT_ANIMATIONS)
	if overrides then
		for name, value in pairs(overrides) do
			merged[name] = value
		end
	end
	return merged
end

local function requireChild(parent: Instance, name: string, className: string): Instance
	local child = parent:FindFirstChild(name)
	assert(child and child:IsA(className), `{parent:GetFullName()} is missing {className} {name}`)
	return child
end

local function getNumber(stats: NumericTable?, names: { string }, fallback: number): number
	if not stats then
		return fallback
	end
	for _, name in ipairs(names) do
		local value = stats[name]
		if typeof(value) == "number" then
			return value
		end
	end
	return fallback
end

local function getString(stats: NumericTable?, names: { string }, fallback: string?): string?
	if not stats then
		return fallback
	end
	for _, name in ipairs(names) do
		local value = stats[name]
		if typeof(value) == "string" and value ~= "" then
			return value
		end
	end
	return fallback
end

local function getCFrame(stats: NumericTable?, names: { string }, fallback: CFrame): CFrame
	if not stats then
		return fallback
	end
	for _, name in ipairs(names) do
		local value = stats[name]
		if typeof(value) == "CFrame" then
			return value
		end
	end
	return fallback
end

local function getStringList(stats: NumericTable?, names: { string }): { string }
	if not stats then
		return {}
	end
	for _, name in ipairs(names) do
		local value = stats[name]
		if typeof(value) == "table" then
			local result = {}
			for _, entry in ipairs(value :: { unknown }) do
				if typeof(entry) == "string" then
					table.insert(result, entry)
				end
			end
			return result
		end
	end
	return {}
end

local function getMagazineCapacity(stats: NumericTable?): number
	return getNumber(stats, { "magazineCapacity" }, 30)
end

local function findWeaponStats(toolTemplate: Tool): NumericTable?
	local statsModule = toolTemplate:FindFirstChild("WeaponStats", true)
	if not statsModule or not statsModule:IsA("ModuleScript") then
		return nil
	end

	local success, result = pcall(require, statsModule)
	if not success or typeof(result) ~= "table" then
		warn(`[SPHController] Could not read {statsModule:GetFullName()}`)
		return nil
	end
	return result :: NumericTable
end

local function resolveToolTemplate(weaponName: string): Tool
	local sph = Workspace:FindFirstChild("SPH")
	assert(sph, "Workspace is missing SPH")
	local tools = sph:FindFirstChild("Tools")
	assert(tools, "Workspace.SPH is missing Tools")
	local template = tools:FindFirstChild(weaponName)
	assert(template and template:IsA("Tool"), `Workspace.SPH.Tools is missing Tool {weaponName}`)
	return template
end

local function resolveWeaponModelTemplate(weaponName: string): Model
	local assets = ReplicatedStorage:FindFirstChild("SPH_Assets")
	assert(assets, "ReplicatedStorage is missing SPH_Assets")
	local models = assets:FindFirstChild("WeaponModels")
	assert(models, "ReplicatedStorage.SPH_Assets is missing WeaponModels")
	local template = models:FindFirstChild(weaponName)
	assert(template and template:IsA("Model"), `SPH_Assets.WeaponModels is missing Model {weaponName}`)
	return template
end

local function resolveHolsterModelTemplate(weaponName: string): Model
	local models = ReplicatedStorage.SPH_Assets.WeaponModels
	local holsterModels = models:FindFirstChild("HolsterModels")
	local template = if holsterModels then holsterModels:FindFirstChild(weaponName) else nil
	if not template then
		template = models:FindFirstChild(weaponName)
	end
	assert(template and template:IsA("Model"), `SPH_Assets is missing a holster model for {weaponName}`)
	return template
end

local function findNamedDescendant(root: Instance, names: { string }): Instance?
	for _, name in ipairs(names) do
		local found = root:FindFirstChild(name, true)
		if found then
			return found
		end
	end
	return nil
end

local function findMuzzlePosition(weaponModel: Model?, tool: Tool?, fallback: BasePart): Vector3
	for _, source in ipairs({ weaponModel, tool }) do
		if not source then
			continue
		end
		local muzzle = findNamedDescendant(source, { "Muzzle", "FirePoint", "Barrel" })
		if muzzle then
			if muzzle:IsA("Attachment") then
				return muzzle.WorldPosition
			elseif muzzle:IsA("BasePart") then
				return muzzle.Position
			end
		end

		local handle = source:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			return handle.Position
		end
	end
	return fallback.Position
end

local function containsName(names: { string }, name: string): boolean
	for _, candidate in ipairs(names) do
		if candidate == name then
			return true
		end
	end
	return false
end

local function prepareWeaponModel(model: Model, animatedParts: { string }): BasePart
	local grip = model.PrimaryPart or model:FindFirstChild("Grip") or model:FindFirstChild("Middle") or model:FindFirstChildWhichIsA("BasePart")
	assert(grip and grip:IsA("BasePart"), `{model:GetFullName()} is missing an attachment BasePart`)
	model.PrimaryPart = grip

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end

	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") and child ~= grip then
			if containsName(animatedParts, child.Name) then
				local motor = Instance.new("Motor6D")
				motor.Name = child.Name
				motor.Part0 = grip
				motor.Part1 = child
				motor.C0 = grip.CFrame:ToObjectSpace(child.CFrame)
				motor.Parent = grip
			else
				local weld = Instance.new("WeldConstraint")
				weld.Name = "SPHControllerWeld"
				weld.Part0 = grip
				weld.Part1 = child
				weld.Parent = grip
			end
		end
	end
	return grip
end

local HOLSTER_HELPER_PART_NAMES = {
	Grip = true,
	Middle = true,
	AimPart = true,
}

local function hideHolsterHelperParts(model: Model): ()
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and HOLSTER_HELPER_PART_NAMES[descendant.Name] then
			descendant.Transparency = 1
			descendant.CastShadow = false
			descendant.CanQuery = false
		end
	end
end

local function createRigJoint(animBase: BasePart, arm: BasePart, name: string, x: number): Motor6D
	local existing = animBase:FindFirstChild(name)
	if existing and existing:IsA("Motor6D") then
		return existing
	end
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = animBase
	motor.Part1 = arm
	motor.C0 = CFrame.new(x, -1, -1) * CFrame.Angles(math.rad(90), 0, 0)
	motor.Parent = animBase
	return motor
end

local function copyArmAppearance(sourceArm: BasePart, rigArm: BasePart): ()
	rigArm.Color = sourceArm.Color
	rigArm.Material = sourceArm.Material
	rigArm.MaterialVariant = sourceArm.MaterialVariant
	rigArm.Reflectance = sourceArm.Reflectance
	rigArm.CastShadow = sourceArm.CastShadow

	for _, child in sourceArm:GetChildren() do
		if child:IsA("Decal") or child:IsA("Texture") or child:IsA("SurfaceAppearance") or child:IsA("SpecialMesh") then
			child:Clone().Parent = rigArm
		end
	end
end

local function applyRigClothing(character: Model, rig: Model): Humanoid?
	local shirt = character:FindFirstChildOfClass("Shirt")
	local characterMeshes = {}
	for _, child in character:GetChildren() do
		if child:IsA("CharacterMesh") then
			table.insert(characterMeshes, child)
		end
	end
	if not shirt and #characterMeshes == 0 then
		return nil
	end

	-- Classic R6 clothing is rendered by a Humanoid; a Shirt alone on the
	-- auxiliary animation rig does not project its sleeves onto the rig arms.
	local appearanceHumanoid = Instance.new("Humanoid")
	appearanceHumanoid.Name = "SPHControllerAppearanceHumanoid"
	appearanceHumanoid.AutoRotate = false
	appearanceHumanoid.BreakJointsOnDeath = false
	appearanceHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	appearanceHumanoid.EvaluateStateMachine = false
	appearanceHumanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	appearanceHumanoid.RequiresNeck = false
	appearanceHumanoid.Parent = rig

	if shirt then
		shirt:Clone().Parent = rig
	end
	for _, characterMesh in characterMeshes do
		characterMesh:Clone().Parent = rig
	end
	return appearanceHumanoid
end

local function createWeaponRig(character: Model, assets: Instance, head: BasePart, characterRightArm: BasePart, characterLeftArm: BasePart): (Model, Animator, BasePart, Motor6D)
	local arms = requireChild(assets, "Arms", "Folder")
	local r6Arms = requireChild(arms, "R6_Arms", "Instance")
	local template = requireChild(r6Arms, "WeaponRig", "Model") :: Model
	local rig = template:Clone()
	rig.Name = "SPHControllerWeaponRig"

	local animBase = requireChild(rig, "AnimBase", "BasePart") :: BasePart
	local rightArm = requireChild(rig, "Right Arm", "BasePart") :: BasePart
	local leftArm = requireChild(rig, "Left Arm", "BasePart") :: BasePart
	for _, descendant in ipairs(rig:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end
	copyArmAppearance(characterRightArm, rightArm)
	rightArm.Transparency = 1
	copyArmAppearance(characterLeftArm, leftArm)
	leftArm.Transparency = 1
	animBase.Transparency = 1
	local appearanceHumanoid = applyRigClothing(character, rig)
	createRigJoint(animBase, rightArm, "RightJoint", 1)
	createRigJoint(animBase, leftArm, "LeftJoint", -1)

	local animationOwner: Humanoid | AnimationController
	if appearanceHumanoid then
		local oldAnimationController = rig:FindFirstChildOfClass("AnimationController")
		if oldAnimationController then
			oldAnimationController:Destroy()
		end
		animationOwner = appearanceHumanoid
	else
		local animationController = rig:FindFirstChildOfClass("AnimationController")
		if not animationController then
			animationController = Instance.new("AnimationController")
			animationController.Parent = rig
		end
		animationOwner = animationController
	end
	local animator = animationOwner:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = animationOwner
	end
	if not rig:FindFirstChild("Weapon") then
		local weaponFolder = Instance.new("Folder")
		weaponFolder.Name = "Weapon"
		weaponFolder.Parent = rig
	end
	rig.Parent = character

	local baseMotor = Instance.new("Motor6D")
	baseMotor.Name = "SPHControllerWeaponRoot"
	baseMotor.Part0 = head
	baseMotor.Part1 = animBase
	baseMotor.C0 = CFrame.new(0, 0, -0.4)
	baseMotor.Parent = head
	return rig, animator, animBase, baseMotor
end

local function waypointContainsCharacter(waypoint: BasePart, character: Model): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { character }
	local zoneHeight = 5
	local zoneSize = Vector3.new(math.max(waypoint.Size.X, 4), zoneHeight, math.max(waypoint.Size.Z, 4))
	local zoneCFrame = waypoint.CFrame * CFrame.new(0, waypoint.Size.Y / 2 + zoneHeight / 2 - 0.1, 0)
	return #Workspace:GetPartBoundsInBox(zoneCFrame, zoneSize, params) > 0
end

local function createTracer(origin: Vector3, hitPosition: Vector3): ()
	local distance = (hitPosition - origin).Magnitude
	if distance <= 0.01 then
		return
	end
	local tracer = Instance.new("Part")
	tracer.Name = "SPHControllerTracer"
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanTouch = false
	tracer.CanQuery = false
	tracer.CastShadow = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = Color3.fromRGB(255, 225, 90)
	tracer.Size = Vector3.new(0.045, 0.045, distance)
	tracer.CFrame = CFrame.lookAt(origin:Lerp(hitPosition, 0.5), hitPosition)
	tracer.Parent = Workspace
	Debris:AddItem(tracer, 0.06)
end

local function findHumanoidFromHit(instance: Instance): Humanoid?
	local current: Instance? = instance
	while current and current ~= Workspace do
		if current:IsA("Model") then
			local humanoid = current:FindFirstChildOfClass("Humanoid")
			if humanoid then
				return humanoid
			end
		end
		current = current.Parent
	end
	return nil
end

local function stopTrack(track: AnimationTrack?, fadeTime: number?): ()
	if track and track.IsPlaying then
		track:Stop(fadeTime or POSE_BLEND_TIME)
	end
end

local function configureInventoryTool(tool: Tool): ()
	for _, descendant in ipairs(tool:GetDescendants()) do
		if descendant:IsA("BaseScript") then
			descendant.Enabled = false
		elseif descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end
	tool.CanBeDropped = false
end

local function normalizeAnimationName(name: string): string
	local withoutSuffix = string.lower(name):gsub("%s*animation$", "")
	return withoutSuffix:gsub("[^%w]", "")
end

local function findAnimation(animations: Instance, requestedName: string): Animation?
	local direct = animations:FindFirstChild(requestedName)
	if direct and direct:IsA("Animation") then
		return direct
	end

	local normalizedRequestedName = normalizeAnimationName(requestedName)
	for _, candidate in ipairs(animations:GetChildren()) do
		if candidate:IsA("Animation") and normalizeAnimationName(candidate.Name) == normalizedRequestedName then
			return candidate
		end
	end
	return nil
end

local function waitForDuration(duration: number, isCancelled: () -> boolean): boolean
	local finishAt = os.clock() + duration
	while os.clock() < finishAt do
		if isCancelled() then
			return false
		end
		task.wait(math.min(0.1, math.max(0, finishAt - os.clock())))
	end
	return true
end

local function runAsyncAction(operation: () -> (boolean, number), shouldAbort: () -> boolean): Promise.Promise<boolean>
	return Promise.new(function(resolve, _reject, onCancel): ()
		local cancelled = false
		if onCancel(function(): ()
			cancelled = true
		end) then
			return
		end

		local succeeded, duration = operation()
		if not succeeded then
			resolve(false)
			return
		end

		local completed = waitForDuration(duration, function(): boolean
			return cancelled or shouldAbort()
		end)
		if not cancelled then
			resolve(completed)
		end
	end)
end

local function waitForTrackCompletion(track: AnimationTrack, fallbackDuration: number, isCancelled: () -> boolean): boolean
	local ended = false
	local endedConnection = track.Ended:Connect(function(): ()
		ended = true
	end)
	local startedAt = os.clock()
	while track.Length <= 0 and not ended and track.IsPlaying and os.clock() - startedAt < 1 do
		if isCancelled() then
			endedConnection:Disconnect()
			return false
		end
		task.wait()
	end

	local timeout = math.max(track.Length, fallbackDuration, 0.05) + 1
	while (track.IsPlaying or track.WeightCurrent > 0.01) and os.clock() - startedAt < timeout do
		if isCancelled() then
			endedConnection:Disconnect()
			return false
		end
		task.wait()
	end

	if (track.IsPlaying or track.WeightCurrent > 0.01) and not isCancelled() then
		-- A few server-owned AnimationTracks can keep IsPlaying true even after
		-- their visible keyframes have ended. Force the bounded fallback to a
		-- clean fade-out so the action can restore its stable idle/aim loop.
		track:Stop(POSE_BLEND_TIME)
		local fadeStartedAt = os.clock()
		while track.WeightCurrent > 0.01 and os.clock() - fadeStartedAt < POSE_BLEND_TIME + 1 do
			if isCancelled() then
				endedConnection:Disconnect()
				return false
			end
			RunService.Heartbeat:Wait()
		end
	end
	endedConnection:Disconnect()
	return not isCancelled()
end

local function waitForTrackWeight(track: AnimationTrack, targetWeight: number, transitionTime: number, isCancelled: () -> boolean): boolean
	local startedAt = os.clock()
	local timeout = math.max(transitionTime, 0.05) + 1
	while os.clock() - startedAt < timeout do
		if isCancelled() then
			return false
		end
		if targetWeight > 0 then
			if track.IsPlaying and track.WeightCurrent >= targetWeight - 0.01 then
				return true
			end
		elseif track.WeightCurrent <= 0.01 then
			return true
		end
		RunService.Heartbeat:Wait()
	end
	return false
end

local function lerpRootFacing(self: SPHController, targetPosition: Vector3, transitionTime: number, isCancelled: () -> boolean): boolean
	local startLook = self.rootPart.CFrame.LookVector
	local flatStartLook = Vector3.new(startLook.X, 0, startLook.Z)
	local startRotation = if flatStartLook.Magnitude > 0.001 then CFrame.lookAt(Vector3.zero, flatStartLook).Rotation else self.rootPart.CFrame.Rotation
	local initialRootPosition = self.rootPart.Position
	local initialFlatDirection = Vector3.new(targetPosition.X - initialRootPosition.X, 0, targetPosition.Z - initialRootPosition.Z)
	self.aimOrientation.Enabled = true
	if initialFlatDirection.Magnitude <= 0.001 then
		self.aimOrientation.CFrame = startRotation
		return true
	end
	if flatStartLook.Magnitude > 0.001 and flatStartLook.Unit:Dot(initialFlatDirection.Unit) >= 0.9999 then
		self.aimOrientation.CFrame = CFrame.lookAt(Vector3.zero, initialFlatDirection).Rotation
		return true
	end
	local startedAt = os.clock()

	while true do
		if isCancelled() then
			return false
		end

		local alpha = if transitionTime <= 0 then 1 else math.clamp((os.clock() - startedAt) / transitionTime, 0, 1)
		local rootPosition = self.rootPart.Position
		local flatDirection = Vector3.new(targetPosition.X - rootPosition.X, 0, targetPosition.Z - rootPosition.Z)
		if flatDirection.Magnitude > 0.001 then
			local targetRotation = CFrame.lookAt(Vector3.zero, flatDirection).Rotation
			-- AlignOrientation owns only rotation. Humanoid and NoobPath remain the
			-- sole owners of root translation, so aiming cannot pin a moving agent.
			self.aimOrientation.CFrame = startRotation:Lerp(targetRotation, alpha)
		end

		if alpha >= 1 then
			return true
		end
		RunService.Heartbeat:Wait()
	end
end

local function waitForWeaponPose(self: SPHController, track: AnimationTrack, isCancelled: () -> boolean): boolean
	-- CharacterClient hides its viewmodel until the equip track has loaded and a
	-- keyed Motor6D transform has actually reached the rig. This prevents the
	-- unanimated weapon root from appearing at the character's head while Roblox
	-- is still loading the first animation frame.
	for _ = 1, 20 do
		if isCancelled() then
			return false
		end
		if track.Length > 0 and track.WeightCurrent > 0.01 then
			for _, descendant in self.weaponRig:GetDescendants() do
				if descendant:IsA("Motor6D") and descendant.Transform ~= CFrame.new() then
					return true
				end
			end
		end
		RunService.Heartbeat:Wait()
	end
	return not isCancelled()
end

function SPHController._setStateAttributes(self: SPHController): ()
	self.character:SetAttribute("SPHAmmo", self.ammo)
	self.character:SetAttribute("SPHReserveAmmo", self.reserveAmmo)
	self.character:SetAttribute("SPHEquipped", self.equipped)
	self.character:SetAttribute("SPHReloading", self.reloading)
	self.character:SetAttribute("SPHStance", self.stance)
	self.character:SetAttribute("SPHGait", self.gait)
	self.character:SetAttribute("SPHSpeedMult", self.speedMult)
end

function SPHController._setWeaponRigVisible(self: SPHController, visible: boolean): ()
	local rigRightArm = self.weaponRig:FindFirstChild("Right Arm")
	local rigLeftArm = self.weaponRig:FindFirstChild("Left Arm")
	if rigRightArm and rigRightArm:IsA("BasePart") then
		rigRightArm.Transparency = if visible then 0 else 1
	end
	if rigLeftArm and rigLeftArm:IsA("BasePart") then
		rigLeftArm.Transparency = if visible then 0 else 1
	end
	self.rightArm.Transparency = if visible then 1 else self.rightArmTransparency
	self.leftArm.Transparency = if visible then 1 else self.leftArmTransparency
	for part, authoredTransparency in self.weaponPartTransparencies do
		if part.Parent then
			part.Transparency = if visible then authoredTransparency else 1
		else
			self.weaponPartTransparencies[part] = nil
		end
	end
end

function SPHController._destroyHolster(self: SPHController): ()
	if self.holsterMotor then
		self.holsterMotor:Destroy()
		self.holsterMotor = nil
	end
	if self.holsterModel then
		self.holsterModel:Destroy()
		self.holsterModel = nil
	end
end

function SPHController._showHolster(self: SPHController): ()
	self:_destroyHolster()
	local torso = self.character:FindFirstChild("Torso") or self.character:FindFirstChild("UpperTorso")
	assert(torso and torso:IsA("BasePart"), `{self.character:GetFullName()} is missing Torso/UpperTorso`)
	local model = resolveHolsterModelTemplate(self.weaponName):Clone()
	model.Name = `Holster_{self.weaponName}`
	local grip = prepareWeaponModel(model, {})
	hideHolsterHelperParts(model)
	model.Parent = self.character
	local motor = Instance.new("Motor6D")
	motor.Name = `Holster_{self.weaponName}`
	motor.Part0 = torso
	motor.Part1 = grip
	motor.C0 = self.holsterPosition
	motor.Parent = torso
	self.holsterModel = model
	self.holsterMotor = motor
end

function SPHController._clearEquippedWeaponModel(self: SPHController): ()
	if self.weaponGripMotor then
		self.weaponGripMotor:Destroy()
		self.weaponGripMotor = nil
	end
	if self.weaponModel then
		self.weaponModel:Destroy()
		self.weaponModel = nil
	end
	table.clear(self.weaponPartTransparencies)
end

function SPHController._createInventoryTool(self: SPHController, weaponName: string): Tool
	if self.weapon then
		self.weapon:Destroy()
	end
	local tool = resolveToolTemplate(weaponName):Clone()
	assert(tool and tool:IsA("Tool"), `Could not clone SPH Tool {weaponName}`)
	configureInventoryTool(tool)
	tool.Parent = self.inventory
	self.weapon = tool
	self.character:SetAttribute("SPHInventoryWeapon", weaponName)
	return tool
end

function SPHController._loadTrack(
	self: SPHController,
	animator: Animator,
	cache: { [string]: AnimationTrack },
	animationName: string?,
	priority: Enum.AnimationPriority,
	looped: boolean
): AnimationTrack?
	if not animationName then
		return nil
	end

	local existing = cache[animationName]
	if existing then
		existing.Priority = priority
		existing.Looped = looped
		return existing
	end

	local animation = if animationName == "DefaultR6Walk" then self.walkAnimation else findAnimation(self.animations, animationName)
	if not animation then
		warn(`[SPHController] Missing SPH animation {animationName}`)
		return nil
	end

	local success, track = pcall(function(): AnimationTrack
		return animator:LoadAnimation(animation)
	end)
	if not success then
		warn(`[SPHController] Failed to load {animationName}: {track}`)
		return nil
	end

	track.Priority = priority
	track.Looped = looped
	cache[animationName] = track
	return track
end

function SPHController._playWeaponAnimation(
	self: SPHController,
	animationName: string?,
	looped: boolean?,
	priority: Enum.AnimationPriority?,
	fadeTime: number?,
	speed: number?
): AnimationTrack?
	stopTrack(self.activeWeaponTrack, fadeTime)
	local track = self:_loadTrack(self.weaponAnimator, self.weaponTracks, animationName, priority or Enum.AnimationPriority.Action, looped == true)
	self.activeWeaponTrack = track
	if track then
		track:Play(fadeTime or POSE_BLEND_TIME)
		if speed then
			track:AdjustSpeed(speed)
		end
	end
	return track
end

function SPHController._playWeaponIdle(self: SPHController, animationName: string?, fadeTime: number?): AnimationTrack?
	local requestedTrack = if animationName then self.weaponTracks[animationName] else nil
	if self.weaponIdleTrack and self.weaponIdleTrack ~= requestedTrack then
		stopTrack(self.weaponIdleTrack, fadeTime)
		self.weaponIdleTrack = nil
	end

	local track = self:_loadTrack(self.weaponAnimator, self.weaponTracks, animationName, Enum.AnimationPriority.Idle, true)
	self.weaponIdleTrack = track
	if track and not track.IsPlaying then
		track:Play(fadeTime or 0)
	end
	return track
end

function SPHController._playMovementAnimation(self: SPHController, animationName: string?, priority: Enum.AnimationPriority?, speed: number?): ()
	stopTrack(self.activeMovementTrack)
	local track = self:_loadTrack(self.animator, self.tracks, animationName, priority or Enum.AnimationPriority.Movement, true)
	self.activeMovementTrack = track
	if track then
		track:Play(POSE_BLEND_TIME)
		if speed then
			track:AdjustSpeed(speed)
		end
	end
end

function SPHController._playStanceAnimation(self: SPHController, animationName: string?, priority: Enum.AnimationPriority?): AnimationTrack?
	stopTrack(self.activeStanceTrack)
	local track = self:_loadTrack(self.animator, self.tracks, animationName, priority or Enum.AnimationPriority.Action, true)
	self.activeStanceTrack = track
	if track then
		track:Play(POSE_BLEND_TIME)
	end
	return track
end

function SPHController._playStanceIdle(self: SPHController): number
	stopTrack(self.activeMovementTrack)
	self.activeMovementTrack = nil
	if self.stance == "Crouching" then
		self:_playStanceAnimation(self.animationNames.crouchIdle, Enum.AnimationPriority.Action)
	elseif self.stance == "Proning" then
		self:_playStanceAnimation(self.animationNames.proneIdle, Enum.AnimationPriority.Action)
	else
		self:_playStanceAnimation(nil)
	end
	if self.equipped and not self.reloading then
		self:_playWeaponIdle(self.animationNames.idle)
	end
	return POSE_BLEND_TIME
end

function SPHController._applyStanceHeight(self: SPHController): ()
	local offset = 0
	if self.stance == "Crouching" then
		offset = self.crouchHipOffset
	elseif self.stance == "Proning" then
		offset = self.proneHipOffset
	end
	self.humanoid.HipHeight = self.defaultHipHeight + offset
	self.character:SetAttribute("SPHHipOffset", offset)
	if self.weaponBaseMotor then
		self.weaponBaseMotor.C0 = self.weaponServerOffset
	end
end

function SPHController._updateHeadPose(self: SPHController): ()
	local neckJoint = self.neckJoint
	local defaultNeckC1 = self.defaultNeckC1
	if not neckJoint or not defaultNeckC1 then
		return
	end

	if self.stance ~= "Proning" then
		neckJoint.C1 = defaultNeckC1
		return
	end

	-- Spearhead corrects the neck's C1 every rendered frame after the prone body
	-- animation pitches the torso forward. PlayerClient sends this value to the
	-- server; NPCs have no PlayerClient, so the controller applies the same pose
	-- locally. Without it, the animated torso also rotates the face into the floor.
	local lookDirection = self.rootPart.CFrame
	local aimTarget = self.aimTarget
	if aimTarget and (aimTarget - self.rootPart.Position).Magnitude > 0.001 then
		lookDirection = CFrame.lookAt(self.rootPart.Position, aimTarget)
	end

	local torsoDirection = self.torso.CFrame.LookVector
	local cameraDirection = self.rootPart.CFrame:ToObjectSpace(lookDirection).LookVector
	local rotationCFrame = CFrame.Angles(0, math.asin(math.clamp(cameraDirection.X, -1, 1)) / 1.15, 0)
		* CFrame.Angles(-math.asin(math.clamp(lookDirection.LookVector.Y, -1, 1)) + math.asin(math.clamp(torsoDirection.Y, -1, 1)), 0, 0)
	neckJoint.C1 = CFrame.new(0, -0.5, 0) * rotationCFrame * CFrame.Angles(-math.rad(90), 0, math.rad(180))
end

function SPHController._playGaitAnimation(self: SPHController, gait: Enums.Movement): ()
	if gait == "CrouchWalk" then
		-- Spearhead keeps the stance pose running beneath the higher-priority
		-- locomotion layer. CrouchMove and ProneMove do not provide a complete
		-- upper-body pose by themselves.
		self:_playStanceAnimation(self.animationNames.crouchIdle, Enum.AnimationPriority.Action)
		self:_playMovementAnimation(self.animationNames.crouchMove, Enum.AnimationPriority.Action2, self.humanoid.WalkSpeed / 6)
	elseif gait == "ProneWalk" then
		self:_playStanceAnimation(self.animationNames.proneIdle, Enum.AnimationPriority.Action)
		self:_playMovementAnimation(self.animationNames.proneMove, Enum.AnimationPriority.Action2, self.humanoid.WalkSpeed / 6)
	else
		self:_playStanceAnimation(nil)
		self:_playMovementAnimation("DefaultR6Walk", Enum.AnimationPriority.Movement, if gait == "Sprint" then 1.65 else 1)
	end

	if self.equipped then
		self:_playWeaponIdle(self.animationNames.idle)
		local activeWeaponTrack = self.activeWeaponTrack
		local weaponActionPlaying = activeWeaponTrack ~= nil and activeWeaponTrack.IsPlaying and activeWeaponTrack.Priority.Value >= Enum.AnimationPriority.Action.Value
		if not weaponActionPlaying and not self.reloading then
			self:_restoreWeaponLoop()
		end
	end
end

function SPHController._configureWeaponStats(self: SPHController, template: Tool, config: Config): ()
	local stats = findWeaponStats(template)
	-- Every weapon starts from the Rifle family. WeaponStats then swaps in any
	-- weapon-specific counterparts, and explicit controller overrides win last.
	-- Rebuilding the table prevents the previously equipped weapon's family from
	-- leaking into a weapon that omits one or more animation fields.
	self.animationNames = mergeAnimationNames(nil)
	self.magazineCapacity = math.max(1, math.floor(getMagazineCapacity(stats)))
	self.ammo = self.magazineCapacity
	self.reserveAmmo = math.max(0, math.floor(config.reserveAmmo or self.magazineCapacity * 3))

	local rawFireRate = getNumber(stats, { "fireRate", "firerate", "rateOfFire" }, 600)
	local inferredFireInterval = if rawFireRate > 10 then 60 / rawFireRate else rawFireRate
	self.fireInterval = math.max(0.01, config.fireInterval or inferredFireInterval)
	self.reloadDuration = math.max(0, config.reloadDuration or getNumber(stats, { "reloadTime", "reloadDuration" }, 4))
	self.range = math.max(1, config.range or getNumber(stats, { "maxRange", "range", "range1" }, 1000))
	self.damage = math.max(0, config.damage or getNumber(stats, { "damage", "damage0", "baseDamage" }, 25))
	self.aimTime = math.max(0, config.aimTime or getNumber(stats, { "aimTime" }, 0.7))
	self.equipSpeedModifier = math.max(0.01, config.equipSpeedModifier or getNumber(stats, { "equipSpeedModifier" }, 1))
	self.weaponServerOffset = getCFrame(stats, { "serverOffset" }, CFrame.new(0, 0, -0.4))
	self.holsterPosition = getCFrame(stats, { "holsterPosition" }, CFrame.new(1, -0.8, 0.5))
	self.animatedWeaponParts = getStringList(stats, { "rigParts", "animatedParts" })

	self.animationNames.equip = getString(stats, { "equipAnim" }, self.animationNames.equip)
	self.animationNames.idle = getString(stats, { "idleAnim" }, self.animationNames.idle)
	self.animationNames.neutral = getString(stats, { "holdUpAnim" }, self.animationNames.neutral)
	self.animationNames.aim = getString(stats, { "aimAnim" }, self.animationNames.aim)
	self.animationNames.fire = getString(stats, { "fireAnim" }, self.animationNames.fire)
	self.animationNames.reload = getString(stats, { "reloadAnim" }, self.animationNames.reload)
	self.animationNames.chamber = getString(stats, { "boltChamber" }, self.animationNames.chamber)
	self.animationNames.close = getString(stats, { "boltClose" }, self.animationNames.close)
	self.animationNames.switch = getString(stats, { "switchAnim" }, self.animationNames.switch)
	self.animationNames.sprint = getString(stats, { "sprintAnim" }, self.animationNames.sprint)
	-- Live Spearhead characters keep MG_Idle on WeaponRig while the Humanoid
	-- animator owns Prone_Move. Rifle_ProneMove is not used by the PKM player rig.
	self.animationNames.weaponProneMove = self.animationNames.idle
	for name, value in pairs(self.animationOverrides) do
		self.animationNames[name] = value
	end
end

function SPHController.GetHumanoid(self: SPHController): Humanoid
	return self.humanoid
end

function SPHController.GetTeamId(self: SPHController): Team.Id
	return self.teamId
end

function SPHController.GetHeadPart(self: SPHController): BasePart
	return self.head
end

function SPHController.GetModel(self: SPHController): Model
	return self.model
end

function SPHController.GetStance(self: SPHController): Enums.Posture
	return self.stance
end

function SPHController.GetGait(self: SPHController): Enums.Movement?
	return self.gait
end

function SPHController.GetAmmo(self: SPHController): (number, number)
	return self.ammo, self.reserveAmmo
end

function SPHController.GetFireInterval(self: SPHController): number
	return self.fireInterval
end

function SPHController.GetAnimationNames(self: SPHController): AnimationNames
	return table.clone(self.animationNames)
end

function SPHController.CanFire(self: SPHController): boolean
	return self.equipped and not self.reloading and self.ammo > 0 and os.clock() >= self.nextShotAt
end

function SPHController._setStanceNow(self: SPHController, stance: Enums.Posture): number
	assert(stance == "Standing" or stance == "Crouching" or stance == "Proning", `Invalid stance {stance}`)
	self.stance = stance
	self:_applyStanceHeight()
	local gait = self.gait
	local transitionDuration: number
	if gait then
		gait = getGaitForStance(gait, stance)
		self.gait = gait
		local speed = getMovementSpeed(self, gait)
		self.humanoid.WalkSpeed = speed
		self.setPathSpeed(speed)
		self:_playGaitAnimation(gait)
		transitionDuration = POSE_BLEND_TIME
	else
		transitionDuration = self:_playStanceIdle()
	end
	self:_setStateAttributes()
	return transitionDuration
end

function SPHController._aimNow(self: SPHController, targetPosition: Vector3, isCancelled: () -> boolean): (AnimationTrack?, boolean, number)
	self.aimTarget = targetPosition
	self.humanoid.AutoRotate = false
	local transitionTime = self.aimTime / (4 * self.aimSpeed)

	self:_playWeaponIdle(self.animationNames.idle)
	local aimTrack: AnimationTrack? = nil
	if self.animationNames.aim then
		aimTrack = self.weaponTracks[self.animationNames.aim]
		if not aimTrack or self.activeWeaponTrack ~= aimTrack or not aimTrack.IsPlaying then
			aimTrack = self:_playWeaponAnimation(self.animationNames.aim, true, Enum.AnimationPriority.Action, transitionTime)
		end
	end

	return aimTrack, lerpRootFacing(self, targetPosition, transitionTime, isCancelled), transitionTime
end

function SPHController._clearAimNow(self: SPHController): (AnimationTrack?, number)
	self.aimTarget = nil
	self.aimOrientation.Enabled = false
	self.humanoid.AutoRotate = true

	local aimAnimationName = self.animationNames.aim
	local aimTrack = if aimAnimationName then self.weaponTracks[aimAnimationName] else nil
	if aimTrack and self.activeWeaponTrack == aimTrack then
		local transitionTime = self.aimTime / (6 * self.aimSpeed)
		stopTrack(aimTrack, transitionTime)
		self.activeWeaponTrack = nil
		if self.equipped and not self.reloading then
			self:_restoreWeaponLoop()
		end
		return aimTrack, transitionTime
	end
	return nil, 0
end

function SPHController._restoreWeaponLoop(self: SPHController): ()
	if not self.equipped or self.reloading then
		return
	end
	self:_playWeaponIdle(self.animationNames.idle)
	if self.aimTarget and self.animationNames.aim then
		local aimTrack = self.weaponTracks[self.animationNames.aim]
		if not aimTrack or self.activeWeaponTrack ~= aimTrack or not aimTrack.IsPlaying then
			self:_playWeaponAnimation(self.animationNames.aim, true, Enum.AnimationPriority.Action, self.aimTime / (4 * self.aimSpeed))
		end
	elseif self.gait == "Sprint" and self.animationNames.sprint then
		local sprintTrack = self.weaponTracks[self.animationNames.sprint]
		if not sprintTrack or self.activeWeaponTrack ~= sprintTrack or not sprintTrack.IsPlaying then
			self:_playWeaponAnimation(self.animationNames.sprint, true, Enum.AnimationPriority.Movement)
		end
	elseif self.gait == "ProneWalk" then
		stopTrack(self.activeWeaponTrack)
		self.activeWeaponTrack = nil
		self:_playWeaponIdle(self.animationNames.weaponProneMove)
	else
		stopTrack(self.activeWeaponTrack)
		self.activeWeaponTrack = nil
	end
end

function SPHController._unequipNow(self: SPHController): ()
	self.equipped = false
	self.reloading = false
	stopTrack(self.activeWeaponTrack)
	self.activeWeaponTrack = nil
	stopTrack(self.weaponIdleTrack)
	self.weaponIdleTrack = nil
	self.humanoid:UnequipTools()
	if self.weapon then
		self.weapon.Parent = self.inventory
	end
	self:_clearEquippedWeaponModel()
	self:_setWeaponRigVisible(false)
	self:_showHolster()
	self:_setStateAttributes()
end

function SPHController._runWeaponAnimationAction(self: SPHController, animationName: string?): Promise.Promise<boolean>
	return Promise.new(function(resolve, _reject, onCancel): ()
		local cancelled = false
		local track: AnimationTrack? = nil
		if
			onCancel(function(): ()
				cancelled = true
				if track and self.activeWeaponTrack == track then
					stopTrack(track)
					self.activeWeaponTrack = nil
					self:_restoreWeaponLoop()
				end
			end)
		then
			return
		end

		if self.destroyed or not self.equipped or self.reloading then
			resolve(false)
			return
		end
		track = self:_playWeaponAnimation(animationName, false, Enum.AnimationPriority.Action)
		if not track then
			resolve(false)
			return
		end

		local completed = waitForTrackCompletion(track, 0.25, function(): boolean
			return cancelled or self.destroyed or not self.equipped
		end)
		if cancelled then
			return
		end
		if completed then
			self:_restoreWeaponLoop()
		end
		resolve(completed)
	end)
end

function SPHController.SetStance(self: SPHController, stance: Enums.Posture): Promise.Promise<boolean>
	return runAsyncAction(function(): (boolean, number)
		if self.destroyed then
			return false, 0
		end
		return true, self:_setStanceNow(stance)
	end, function(): boolean
		return self.destroyed
	end)
end

function SPHController.Aim(self: SPHController, targetPosition: Vector3): Promise.Promise<boolean>
	return Promise.new(function(resolve, _reject, onCancel): ()
		local cancelled = false
		local track: AnimationTrack? = nil
		if
			onCancel(function(): ()
				cancelled = true
				if track and self.activeWeaponTrack == track then
					stopTrack(track, 0)
					self.activeWeaponTrack = nil
				end
			end)
		then
			return
		end

		if self.destroyed or self.reloading or not self.equipped then
			resolve(false)
			return
		end

		local transitionTime: number
		local completed: boolean
		track, completed, transitionTime = self:_aimNow(targetPosition, function(): boolean
			return cancelled or self.destroyed or self.reloading or not self.equipped
		end)
		if cancelled then
			if track and self.activeWeaponTrack == track then
				stopTrack(track, 0)
				self.activeWeaponTrack = nil
			end
			return
		end
		if completed and track then
			completed = waitForTrackWeight(track, 1, transitionTime, function(): boolean
				return cancelled or self.destroyed or self.reloading or not self.equipped
			end)
		end
		if not cancelled then
			resolve(completed)
		end
	end)
end

function SPHController.ClearAim(self: SPHController): Promise.Promise<boolean>
	return Promise.new(function(resolve, _reject, onCancel): ()
		local cancelled = false
		local track: AnimationTrack? = nil
		if onCancel(function(): ()
			cancelled = true
			stopTrack(track, 0)
		end) then
			return
		end

		if self.destroyed then
			resolve(false)
			return
		end

		local transitionTime: number
		track, transitionTime = self:_clearAimNow()
		local completed = if track
			then waitForTrackWeight(track, 0, transitionTime, function(): boolean
				return cancelled or self.destroyed
			end)
			else true
		if not cancelled then
			resolve(completed)
		end
	end)
end

function SPHController.Equip(self: SPHController, weaponName: string?): Promise.Promise<boolean>
	return Promise.new(function(resolve, _reject, onCancel): ()
		local cancelled = false
		local track: AnimationTrack? = nil
		if onCancel(function(): ()
			cancelled = true
			if self.equipped then
				self:_unequipNow()
			end
		end) then
			return
		end

		if self.destroyed or self.reloading then
			resolve(false)
			return
		end

		local requestedWeapon = weaponName or self.weaponName
		if self.equipped and self.weapon and requestedWeapon == self.weaponName then
			resolve(true)
			return
		end

		local template = resolveToolTemplate(requestedWeapon)
		if requestedWeapon ~= self.weaponName then
			self:_unequipNow()
			self:_configureWeaponStats(template, {})
			self.weaponName = requestedWeapon
			self.weaponBaseMotor.C0 = self.weaponServerOffset
			self:_createInventoryTool(requestedWeapon)
			self:_showHolster()
		end
		self.weaponName = requestedWeapon

		local tool = self.weapon or self:_createInventoryTool(requestedWeapon)
		self.humanoid:UnequipTools()
		tool.Parent = self.inventory
		self:_destroyHolster()
		self:_clearEquippedWeaponModel()
		self.humanoid:EquipTool(tool)
		if tool.Parent ~= self.character then
			tool.Parent = self.character
		end

		local model = resolveWeaponModelTemplate(requestedWeapon):Clone()
		model.Name = requestedWeapon
		local grip = prepareWeaponModel(model, self.animatedWeaponParts)
		local weaponFolder = self.weaponRig:FindFirstChild("Weapon")
		assert(weaponFolder, `{self.weaponRig:GetFullName()} is missing Weapon`)
		model.Parent = weaponFolder
		local gripMotor = Instance.new("Motor6D")
		gripMotor.Name = "GunMotor"
		gripMotor.Part0 = self.weaponAnimBase
		gripMotor.Part1 = grip
		gripMotor.Parent = self.weaponAnimBase
		self.weaponModel = model
		self.weaponGripMotor = gripMotor
		table.clear(self.weaponPartTransparencies)
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				self.weaponPartTransparencies[descendant] = descendant.Transparency
			end
		end
		self:_setWeaponRigVisible(false)
		self.equipped = true
		self:_setStateAttributes()

		track = self:_playWeaponAnimation(self.animationNames.equip, false, Enum.AnimationPriority.Action2, 0, self.equipSpeedModifier)
		-- CharacterClient starts idle immediately underneath Action2 equip. Keeping
		-- the stable loop alive removes the default-pose gap at the end of equip.
		self:_playWeaponIdle(self.animationNames.idle, 0)
		-- CharacterClient also preloads its aim track during equip. Loading it here
		-- lets the later aim fade begin immediately instead of pausing on first use.
		self:_loadTrack(self.weaponAnimator, self.weaponTracks, self.animationNames.aim, Enum.AnimationPriority.Action, true)
		if track then
			waitForWeaponPose(self, track, function(): boolean
				return cancelled or self.destroyed or not self.equipped
			end)
		end
		if cancelled then
			return
		end
		if self.equipped then
			self:_setWeaponRigVisible(true)
		end

		local completed = true
		if track then
			completed = waitForTrackCompletion(track, 0.5 / self.equipSpeedModifier, function(): boolean
				return cancelled or self.destroyed or not self.equipped
			end)
		end
		if cancelled then
			return
		end
		if track and self.activeWeaponTrack == track then
			self.activeWeaponTrack = nil
		end
		if completed and self.equipped then
			self:_restoreWeaponLoop()
		end
		resolve(completed and self.equipped)
	end)
end

function SPHController.Unequip(self: SPHController): Promise.Promise<boolean>
	return runAsyncAction(function(): (boolean, number)
		if self.destroyed then
			return false, 0
		end
		self:_unequipNow()
		return true, 0
	end, function(): boolean
		return self.destroyed
	end)
end

function SPHController.Fire(self: SPHController): Promise.Promise<boolean>
	return Promise.new(function(resolve, _reject, onCancel): ()
		local cancelled = false
		local track: AnimationTrack? = nil
		if
			onCancel(function(): ()
				cancelled = true
				if track and self.activeWeaponTrack == track then
					stopTrack(track)
					self.activeWeaponTrack = nil
					self:_restoreWeaponLoop()
				end
			end)
		then
			return
		end

		if self.destroyed or not self:CanFire() then
			resolve(false)
			return
		end

		self.ammo -= 1
		self.nextShotAt = os.clock() + self.fireInterval
		self:_setStateAttributes()

		local origin = findMuzzlePosition(self.weaponModel, self.weapon, self.rootPart)
		local direction: Vector3
		if self.aimTarget and (self.aimTarget - origin).Magnitude > 0.001 then
			direction = (self.aimTarget - origin).Unit
		else
			direction = self.rootPart.CFrame.LookVector
		end

		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = { self.character }
		local result = Workspace:Raycast(origin, direction * self.range, raycastParams)
		local hitPosition = origin + direction * self.range
		if result then
			hitPosition = result.Position
			local hitHumanoid = findHumanoidFromHit(result.Instance)
			if hitHumanoid and hitHumanoid ~= self.humanoid then
				hitHumanoid:TakeDamage(self.damage)
			end
		end
		createTracer(origin, hitPosition)
		AgentFired:Fire(self.teamId, self.head.Position)

		local effectsSource: Instance? = self.weaponModel or self.weapon
		if effectsSource then
			local fireSound = findNamedDescendant(effectsSource, { "Fire", "FireSound", "Shoot" })
			if fireSound and fireSound:IsA("Sound") then
				fireSound:Play()
			end
			local muzzle = findNamedDescendant(effectsSource, { "Muzzle", "FirePoint" })
			if muzzle then
				for _, descendant in ipairs(muzzle:GetDescendants()) do
					if descendant:IsA("ParticleEmitter") then
						descendant:Emit(1)
					end
				end
			end
		end

		if self.animationNames.fire then
			track = self:_playWeaponAnimation(self.animationNames.fire, false, Enum.AnimationPriority.Action)
		end
		local completed = true
		if track then
			completed = waitForTrackCompletion(track, 0.25, function(): boolean
				return cancelled or self.destroyed or not self.equipped
			end)
		end
		if cancelled then
			return
		end
		if completed and track then
			self:_restoreWeaponLoop()
		end
		resolve(completed)
	end)
end

function SPHController.Reload(self: SPHController): Promise.Promise<boolean>
	return Promise.new(function(resolve, _reject, onCancel): ()
		local cancelled = false
		local track: AnimationTrack? = nil
		if
			onCancel(function(): ()
				cancelled = true
				self.reloading = false
				self:_setStateAttributes()
				if track and self.activeWeaponTrack == track then
					stopTrack(track)
					self.activeWeaponTrack = nil
					self:_restoreWeaponLoop()
				end
			end)
		then
			return
		end

		if self.destroyed or not self.equipped or self.reloading then
			resolve(false)
			return
		end
		if self.ammo >= self.magazineCapacity or self.reserveAmmo <= 0 then
			resolve(false)
			return
		end

		self.reloading = true
		self:_setStateAttributes()
		track = self:_playWeaponAnimation(self.animationNames.reload, false, Enum.AnimationPriority.Action)
		local completed = if track
			then waitForTrackCompletion(track, self.reloadDuration, function(): boolean
				return cancelled or self.destroyed or not self.equipped
			end)
			else waitForDuration(self.reloadDuration, function(): boolean
				return cancelled or self.destroyed or not self.equipped
			end)
		if cancelled then
			return
		end
		if not completed then
			self.reloading = false
			self:_setStateAttributes()
			resolve(false)
			return
		end

		local needed = self.magazineCapacity - self.ammo
		local transferred = math.min(needed, self.reserveAmmo)
		self.ammo += transferred
		self.reserveAmmo -= transferred
		self.reloading = false
		self:_setStateAttributes()
		self:_restoreWeaponLoop()
		resolve(true)
	end)
end

function SPHController.Chamber(self: SPHController): Promise.Promise<boolean>
	return self:_runWeaponAnimationAction(self.animationNames.chamber)
end

function SPHController.CloseBolt(self: SPHController): Promise.Promise<boolean>
	return self:_runWeaponAnimationAction(self.animationNames.close)
end

function SPHController.SwitchFireMode(self: SPHController): Promise.Promise<boolean>
	return self:_runWeaponAnimationAction(self.animationNames.switch)
end

local function runOwnedPath(self: SPHController, serial: number, destination: Vector3): boolean
	if self.destroyed or self.activeMoveSerial ~= serial then
		return false
	end

	self.runPath(destination)
	if self.destroyed or self.activeMoveSerial ~= serial then
		-- NoobPath.Run can yield while computing. If StopMoving cancelled this
		-- operation during that yield, Run may resume and start travelling again.
		-- Stop it a second time after the stale call returns.
		if not self.destroyed and self.activeMoveSerial == nil then
			self.stopPath()
		end
		return false
	end
	if self.terminalPathFailure ~= nil then
		return false
	end

	return true
end

local function finishOwnedMovement(self: SPHController, serial: number): ()
	if self.activeMoveSerial ~= serial then
		return
	end

	self.activeMoveSerial = nil
	self.stopPath()
	self.gait = nil
	self:_playStanceIdle()
	self:_setStateAttributes()
end

function SPHController.MoveTo(self: SPHController, destination: Vector3 | BasePart, gait: Enums.Movement): boolean
	if self.destroyed then
		return false
	end

	self.moveSerial += 1
	local serial = self.moveSerial
	self.activeMoveSerial = serial
	if gait == "Sprint" then
		self.stance = "Standing"
	elseif gait == "CrouchWalk" then
		self.stance = "Crouching"
	elseif gait == "ProneWalk" then
		self.stance = "Proning"
	else
		assert(gait == "Walk", `Invalid gait {gait}`)
		self.stance = "Standing"
	end
	local speed = getMovementSpeed(self, gait)

	-- A previous request may still have a locomotion track while this path is
	-- being computed. Return to the stance idle until NoobPath accepts the new
	-- route so an immediate TargetUnreachable never flashes a walking pose.
	self.gait = nil
	self:_applyStanceHeight()
	self.humanoid.WalkSpeed = speed
	self.setPathSpeed(speed)
	self:_playStanceIdle()
	self:_setStateAttributes()
	local destinationPosition = if typeof(destination) == "Instance" then (destination :: BasePart).Position else destination :: Vector3
	self.pendingPathFailure = nil
	self.terminalPathFailure = nil
	self.character:SetAttribute("SPHPathError", nil)
	if not runOwnedPath(self, serial, destinationPosition) then
		finishOwnedMovement(self, serial)
		return false
	end

	self.gait = gait
	self:_playGaitAnimation(gait)
	self:_setStateAttributes()

	local startedAt = os.clock()
	local lastSampleAt = startedAt
	local lastRepathAt = startedAt
	local slowElapsed = 0
	local reached = false
	while not self.destroyed and self.activeMoveSerial == serial do
		local now = os.clock()
		local sampleDelta = now - lastSampleAt
		lastSampleAt = now
		local offset = self.rootPart.Position - destinationPosition
		local closeEnough = Vector3.new(offset.X, 0, offset.Z).Magnitude <= self.reachDistance
		local touchedWaypoint = if typeof(destination) == "Instance" then waypointContainsCharacter(destination :: BasePart, self.character) else closeEnough
		local reachedDestination = if typeof(destination) == "Instance" then touchedWaypoint else closeEnough
		if reachedDestination then
			reached = true
			if typeof(destination) == "Instance" then
				self.character:SetAttribute("SPHWaypointContact", (destination :: BasePart).Name)
			end
			break
		end
		if self.humanoid.Health <= 0 or now - startedAt >= self.moveTimeout then
			break
		end
		if self.terminalPathFailure then
			break
		end

		if self.repathEnabled then
			if self.humanoid.FloorMaterial == Enum.Material.Air then
				slowElapsed = 0
			else
				local velocity = self.rootPart.AssemblyLinearVelocity
				local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
				if horizontalSpeed < self.repathVelocityThreshold then
					slowElapsed += sampleDelta
				else
					slowElapsed = 0
				end
			end

			local repathReason = self.pendingPathFailure
			if not repathReason and slowElapsed >= self.repathStuckDuration then
				repathReason = "LowVelocity"
			end

			if repathReason and now - lastRepathAt >= self.repathCooldown then
				self.pendingPathFailure = nil
				self.pathRepathCount += 1
				self.character:SetAttribute("SPHPathRepathCount", self.pathRepathCount)
				self.character:SetAttribute("SPHPathRepathReason", repathReason)
				if not runOwnedPath(self, serial, destinationPosition) then
					break
				end
				lastRepathAt = now
				slowElapsed = 0
			end
		end
		task.wait(0.1)
	end

	finishOwnedMovement(self, serial)
	if reached then
		self.pendingPathFailure = nil
		self.terminalPathFailure = nil
		self.character:SetAttribute("SPHPathError", nil)
	end
	return reached
end

function SPHController.StopMoving(self: SPHController): ()
	self.moveSerial += 1
	self.activeMoveSerial = nil
	self.pendingPathFailure = nil
	self.terminalPathFailure = nil
	self.stopPath()
	self.gait = nil
	self:_playStanceIdle()
	self:_setStateAttributes()
end

function SPHController.Destroy(self: SPHController): ()
	if self.destroyed then
		return
	end
	self.destroyed = true
	self:StopMoving()
	self:_unequipNow()
	self:_clearAimNow()
	if self.headPoseConnection then
		self.headPoseConnection:Disconnect()
		self.headPoseConnection = nil
	end
	if self.neckJoint and self.defaultNeckC1 then
		self.neckJoint.C1 = self.defaultNeckC1
	end
	for _, track in pairs(self.tracks) do
		stopTrack(track)
		track:Destroy()
	end
	table.clear(self.tracks)
	for _, track in pairs(self.weaponTracks) do
		stopTrack(track)
		track:Destroy()
	end
	table.clear(self.weaponTracks)
	self:_destroyHolster()
	if self.weapon then
		self.weapon:Destroy()
		self.weapon = nil
	end
	self.weaponRig:Destroy()
	self.inventory:Destroy()
	self.walkAnimation:Destroy()
	self.aimOrientation:Destroy()
	self.aimAttachment:Destroy()
	self.destroyPath()
end

function SPHController.new(character: Model, teamId: Team.Id, config: Config?): SPHController
	assert(teamId ~= "", "SPHController teamId must not be empty")
	local controllerConfig: Config = config or {}
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	assert(humanoid, `{character:GetFullName()} is missing a Humanoid`)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	assert(rootPart and rootPart:IsA("BasePart"), `{character:GetFullName()} is missing HumanoidRootPart`)
	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
	assert(torso and torso:IsA("BasePart"), `{character:GetFullName()} is missing Torso/UpperTorso`)
	local neck = torso:FindFirstChild("Neck")
	local neckJoint = if neck and neck:IsA("Motor6D") then neck else nil
	local head = character:FindFirstChild("Head")
	assert(head and head:IsA("BasePart"), `{character:GetFullName()} is missing Head`)
	local rightArm = character:FindFirstChild("Right Arm") or character:FindFirstChild("RightUpperArm")
	assert(rightArm and rightArm:IsA("BasePart"), `{character:GetFullName()} is missing a right arm`)
	local leftArm = character:FindFirstChild("Left Arm") or character:FindFirstChild("LeftUpperArm")
	assert(leftArm and leftArm:IsA("BasePart"), `{character:GetFullName()} is missing a left arm`)

	local model = humanoid.Parent
	local aimAttachment = Instance.new("Attachment")
	aimAttachment.Name = "SPHControllerAimAttachment"
	aimAttachment.Parent = rootPart
	local aimOrientation = Instance.new("AlignOrientation")
	aimOrientation.Name = "SPHControllerAimOrientation"
	aimOrientation.Attachment0 = aimAttachment
	aimOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	aimOrientation.RigidityEnabled = true
	aimOrientation.MaxTorque = math.huge
	aimOrientation.MaxAngularVelocity = math.huge
	aimOrientation.Enabled = false
	aimOrientation.Parent = rootPart

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local assets = requireChild(ReplicatedStorage, "SPH_Assets", "Folder")
	local animations = requireChild(assets, "Animations", "Folder")
	local walkAnimation = Instance.new("Animation")
	walkAnimation.Name = "SPHControllerDefaultR6Walk"
	walkAnimation.AnimationId = controllerConfig.walkAnimationId or DEFAULT_R6_WALK_ANIMATION
	walkAnimation.Parent = character
	local weaponName = controllerConfig.weaponName or "PKM"
	local template = resolveToolTemplate(weaponName)
	local animationOverrides = table.clone(controllerConfig.animationNames or {}) :: AnimationNames
	local oldRig = character:FindFirstChild("SPHControllerWeaponRig")
	if oldRig then
		oldRig:Destroy()
	end
	local oldInventory = character:FindFirstChild("SPHInventory")
	if oldInventory then
		oldInventory:Destroy()
	end
	local inventory = Instance.new("Folder")
	inventory.Name = "SPHInventory"
	inventory.Parent = character
	local weaponRig, weaponAnimator, weaponAnimBase, weaponBaseMotor = createWeaponRig(character, assets, head, rightArm, leftArm)

	local pathfinder = NoobPath.Humanoid(character, DefaultNoobPathConfig.AgentParams, DefaultNoobPathConfig.Precise)
	pathfinder.Timeout = DefaultNoobPathConfig.Timeout
	pathfinder.Visualize = DefaultNoobPathConfig.Visualize
	local pathDestroyed = false
	local self = setmetatable({
		teamId = teamId,
		character = character,
		humanoid = humanoid,
		model = model,
		animator = animator,
		rootPart = rootPart,
		aimAttachment = aimAttachment,
		aimOrientation = aimOrientation,
		head = head,
		torso = torso,
		neckJoint = neckJoint,
		defaultNeckC1 = if neckJoint then neckJoint.C1 else nil,
		headPoseConnection = nil,
		animations = animations,
		weaponName = weaponName,
		weapon = nil,
		weaponModel = nil,
		weaponPartTransparencies = {},
		weaponGripMotor = nil,
		weaponAnimBase = weaponAnimBase,
		weaponBaseMotor = weaponBaseMotor,
		weaponRig = weaponRig,
		weaponAnimator = weaponAnimator,
		weaponTracks = {},
		inventory = inventory,
		holsterModel = nil,
		holsterMotor = nil,
		holsterPosition = CFrame.new(1, -0.8, 0.5),
		animatedWeaponParts = {},
		rightArm = rightArm,
		leftArm = leftArm,
		rightArmTransparency = rightArm.Transparency,
		leftArmTransparency = leftArm.Transparency,
		weaponServerOffset = CFrame.new(0, 0, -0.4),
		walkAnimation = walkAnimation,
		magazineCapacity = 1,
		reserveAmmo = 0,
		ammo = 0,
		fireInterval = 0.1,
		reloadDuration = 4,
		range = 1000,
		damage = 25,
		aimTime = controllerConfig.aimTime or 0.7,
		aimSpeed = math.max(0.01, controllerConfig.aimSpeed or 1),
		equipSpeedModifier = controllerConfig.equipSpeedModifier or 1,
		walkSpeed = controllerConfig.walkSpeed or 12,
		sprintSpeed = controllerConfig.sprintSpeed or 20,
		crouchSpeed = controllerConfig.crouchSpeed or 7,
		proneSpeed = controllerConfig.proneSpeed or 3,
		speedMult = math.max(0, controllerConfig.speedMult or 1),
		reachDistance = controllerConfig.reachDistance or 2.5,
		moveTimeout = controllerConfig.moveTimeout or 30,
		repathEnabled = controllerConfig.repathEnabled ~= false,
		repathVelocityThreshold = math.max(0, controllerConfig.repathVelocityThreshold or 0.75),
		repathStuckDuration = math.max(0.1, controllerConfig.repathStuckDuration or 1.5),
		repathCooldown = math.max(0.1, controllerConfig.repathCooldown or 0.75),
		pendingPathFailure = nil,
		terminalPathFailure = nil,
		pathRepathCount = 0,
		defaultHipHeight = humanoid.HipHeight,
		crouchHipOffset = controllerConfig.crouchHipOffset or -0.15,
		-- Spearhead's CharacterMovement uses an absolute R6 HipHeight of -2 while
		-- prone. The neck C1 correction above preserves face clearance at this height.
		proneHipOffset = controllerConfig.proneHipOffset or -2,
		animationOverrides = animationOverrides,
		animationNames = mergeAnimationNames(nil),
		tracks = {},
		activeStanceTrack = nil,
		activeMovementTrack = nil,
		activeWeaponTrack = nil,
		weaponIdleTrack = nil,
		aimTarget = nil,
		stance = "Standing" :: Enums.Posture,
		gait = nil,
		nextShotAt = 0,
		reloading = false,
		equipped = false,
		destroyed = false,
		moveSerial = 0,
		activeMoveSerial = nil,
		runPath = function(destination: Vector3): ()
			if pathDestroyed then
				return
			end
			pathfinder:Run(destination)
		end,
		stopPath = function(): ()
			if pathDestroyed then
				return
			end
			pathfinder:Stop()
		end,
		destroyPath = function(): ()
			if pathDestroyed then
				return
			end
			pathDestroyed = true
			pathfinder:Destroy()
		end,
		setPathSpeed = function(speed: number): ()
			if not pathDestroyed then
				pathfinder.Speed = speed
			end
		end,
	}, SPHController)

	pathfinder.Error:Connect(function(reason: string): ()
		self.terminalPathFailure = reason
		character:SetAttribute("SPHPathError", reason)
		if reason ~= "TargetUnreachable" then
			warn(`[SPHController] NoobPath error for {character.Name}: {reason}`)
		end
	end)
	pathfinder.Trapped:Connect(function(reason: string): ()
		self.pendingPathFailure = `Trapped:{reason}`
		character:SetAttribute("SPHPathError", reason)
	end)
	pathfinder.Reached:Connect(function(_waypoint: unknown, partial: boolean?): ()
		self.pendingPathFailure = nil
		if partial then
			self.terminalPathFailure = "PartialPath"
			character:SetAttribute("SPHPathError", "PartialPath")
		else
			self.terminalPathFailure = nil
			character:SetAttribute("SPHPathError", nil)
		end
	end)

	self:_configureWeaponStats(template, controllerConfig)
	self.weaponBaseMotor.C0 = self.weaponServerOffset
	self:_createInventoryTool(weaponName)
	self:_showHolster()
	character:SetAttribute("SPHPathRepathCount", 0)
	self.headPoseConnection = RunService.Heartbeat:Connect(function(): ()
		if not self.destroyed then
			self:_updateHeadPose()
		end
	end)
	self:_setStateAttributes()
	return self
end

return SPHController
