--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local NoobPath = require(ReplicatedStorage.Packages.NoobPath)
local CompySharedScripts = ReplicatedStorage.CompyAgent
local DefaultNoobPathConfig = require(CompySharedScripts.Config.NoobPathConfig)

local SPHController = {}
SPHController.__index = SPHController

-- NPC-facing boundary for Spearhead assets. This controller intentionally does not
-- invoke Spearhead's Player remotes or install SPH_Character client scripts.

export type Stance = "Standing" | "Crouching" | "Proning"
export type Gait = "Walk" | "Sprint" | "CrouchWalk" | "ProneWalk"

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
	walkSpeed: number?,
	sprintSpeed: number?,
	crouchSpeed: number?,
	proneSpeed: number?,
	reachDistance: number?,
	moveTimeout: number?,
	walkAnimationId: string?,
	crouchHipOffset: number?,
	proneHipOffset: number?,
	animationNames: AnimationNames?,
}

type NumericTable = { [string]: unknown }

type ControllerData = {
	character: Model,
	humanoid: Humanoid,
	animator: Animator,
	rootPart: BasePart,
	torso: BasePart,
	neckJoint: Motor6D?,
	defaultNeckC1: CFrame?,
	headPoseConnection: RBXScriptConnection?,
	animations: Instance,
	weaponName: string,
	weapon: Tool?,
	weaponModel: Model?,
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
	walkSpeed: number,
	sprintSpeed: number,
	crouchSpeed: number,
	proneSpeed: number,
	reachDistance: number,
	moveTimeout: number,
	defaultHipHeight: number,
	crouchHipOffset: number,
	proneHipOffset: number,
	animationOverrides: AnimationNames,
	animationNames: AnimationNames,
	tracks: { [string]: AnimationTrack },
	activeStanceTrack: AnimationTrack?,
	activeMovementTrack: AnimationTrack?,
	activeWeaponTrack: AnimationTrack?,
	aimTarget: Vector3?,
	stance: Stance,
	gait: Gait?,
	nextShotAt: number,
	reloading: boolean,
	equipped: boolean,
	destroyed: boolean,
	moveSerial: number,
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

local function getMagazineCapacity(toolTemplate: Tool, stats: NumericTable?): number
	local magazineAmmo = toolTemplate:FindFirstChild("MagAmmo", true)
	if magazineAmmo and magazineAmmo:IsA("IntConstrainedValue") then
		return magazineAmmo.MaxValue
	elseif magazineAmmo and magazineAmmo:IsA("IntValue") then
		return magazineAmmo.Value
	end
	return getNumber(stats, { "magSize", "magazineSize", "ammo" }, 100)
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
	local grip = model.PrimaryPart
		or model:FindFirstChild("Grip")
		or model:FindFirstChild("Middle")
		or model:FindFirstChildWhichIsA("BasePart")
	assert(grip and grip:IsA("BasePart"), `{model:GetFullName()} is missing an attachment BasePart`)
	model.PrimaryPart = grip

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = true
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

local function createWeaponRig(
	character: Model,
	assets: Instance,
	head: BasePart,
	characterRightArm: BasePart,
	characterLeftArm: BasePart
): (Model, Animator, BasePart, Motor6D)
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
	rightArm.Color = characterRightArm.Color
	rightArm.Material = characterRightArm.Material
	rightArm.Transparency = 1
	leftArm.Color = characterLeftArm.Color
	leftArm.Material = characterLeftArm.Material
	leftArm.Transparency = 1
	animBase.Transparency = 1
	createRigJoint(animBase, rightArm, "RightJoint", 1)
	createRigJoint(animBase, leftArm, "LeftJoint", -1)

	local animationController = rig:FindFirstChildOfClass("AnimationController")
	if not animationController then
		animationController = Instance.new("AnimationController")
		animationController.Parent = rig
	end
	local animator = animationController:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = animationController
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

local function stopTrack(track: AnimationTrack?): ()
	if track and track.IsPlaying then
		track:Stop(0.15)
	end
end

local function configureInventoryTool(tool: Tool): ()
	for _, descendant in ipairs(tool:GetDescendants()) do
		if descendant:IsA("BaseScript") then
			descendant.Enabled = false
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

local function waitForTrackLength(track: AnimationTrack, timeout: number): number
	local startedAt = os.clock()
	while track.Length <= 0 and os.clock() - startedAt < timeout do
		task.wait()
	end
	return track.Length
end

function SPHController._setStateAttributes(self: SPHController): ()
	self.character:SetAttribute("SPHAmmo", self.ammo)
	self.character:SetAttribute("SPHReserveAmmo", self.reserveAmmo)
	self.character:SetAttribute("SPHEquipped", self.equipped)
	self.character:SetAttribute("SPHReloading", self.reloading)
	self.character:SetAttribute("SPHStance", self.stance)
	self.character:SetAttribute("SPHGait", self.gait)
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
	priority: Enum.AnimationPriority?
): AnimationTrack?
	stopTrack(self.activeWeaponTrack)
	local track = self:_loadTrack(
		self.weaponAnimator,
		self.weaponTracks,
		animationName,
		priority or Enum.AnimationPriority.Action,
		looped == true
	)
	self.activeWeaponTrack = track
	if track then
		track:Play(0.12)
	end
	return track
end

function SPHController._playMovementAnimation(
	self: SPHController,
	animationName: string?,
	priority: Enum.AnimationPriority?,
	speed: number?
): ()
	stopTrack(self.activeMovementTrack)
	local track = self:_loadTrack(
		self.animator,
		self.tracks,
		animationName,
		priority or Enum.AnimationPriority.Movement,
		true
	)
	self.activeMovementTrack = track
	if track then
		track:Play(0.15)
		if speed then
			track:AdjustSpeed(speed)
		end
	end
end

function SPHController._playStanceAnimation(
	self: SPHController,
	animationName: string?,
	priority: Enum.AnimationPriority?
): ()
	stopTrack(self.activeStanceTrack)
	local track = self:_loadTrack(
		self.animator,
		self.tracks,
		animationName,
		priority or Enum.AnimationPriority.Action,
		true
	)
	self.activeStanceTrack = track
	if track then
		track:Play(0.15)
	end
end

function SPHController._playStanceIdle(self: SPHController): ()
	stopTrack(self.activeMovementTrack)
	self.activeMovementTrack = nil
	if self.stance == "Crouching" then
		self:_playStanceAnimation(self.animationNames.crouchIdle, Enum.AnimationPriority.Action)
	elseif self.stance == "Proning" then
		self:_playStanceAnimation(self.animationNames.proneIdle, Enum.AnimationPriority.Action)
	else
		self:_playStanceAnimation(nil)
	end
	if self.equipped then
		self:_playWeaponAnimation(self.animationNames.idle, true, Enum.AnimationPriority.Idle)
	end
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
	local rotationCFrame = CFrame.Angles(
		0,
		math.asin(math.clamp(cameraDirection.X, -1, 1)) / 1.15,
		0
	) * CFrame.Angles(
		-math.asin(math.clamp(lookDirection.LookVector.Y, -1, 1))
			+ math.asin(math.clamp(torsoDirection.Y, -1, 1)),
		0,
		0
	)
	neckJoint.C1 = CFrame.new(0, -0.5, 0)
		* rotationCFrame
		* CFrame.Angles(-math.rad(90), 0, math.rad(180))
end

function SPHController._playGaitAnimation(self: SPHController, gait: Gait): ()
	if gait == "CrouchWalk" then
		-- Spearhead keeps the stance pose running beneath the higher-priority
		-- locomotion layer. CrouchMove and ProneMove do not provide a complete
		-- upper-body pose by themselves.
		self:_playStanceAnimation(self.animationNames.crouchIdle, Enum.AnimationPriority.Action)
		self:_playMovementAnimation(
			self.animationNames.crouchMove,
			Enum.AnimationPriority.Action2,
			self.humanoid.WalkSpeed / 6
		)
	elseif gait == "ProneWalk" then
		self:_playStanceAnimation(self.animationNames.proneIdle, Enum.AnimationPriority.Action)
		self:_playMovementAnimation(
			self.animationNames.proneMove,
			Enum.AnimationPriority.Action2,
			self.humanoid.WalkSpeed / 6
		)
	else
		self:_playStanceAnimation(nil)
		self:_playMovementAnimation(
			"DefaultR6Walk",
			Enum.AnimationPriority.Movement,
			if gait == "Sprint" then 1.65 else 1
		)
	end

	if self.equipped then
		if gait == "Sprint" then
			self:_playWeaponAnimation(self.animationNames.sprint, true, Enum.AnimationPriority.Movement)
		elseif gait == "ProneWalk" then
			-- Spearhead keeps the weapon rig on its idle loop while the humanoid
			-- supplies the equipped prone crawl pose.
			self:_playWeaponAnimation(self.animationNames.weaponProneMove, true, Enum.AnimationPriority.Idle)
		else
			self:_playWeaponAnimation(self.animationNames.idle, true, Enum.AnimationPriority.Idle)
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
	self.magazineCapacity = math.max(
		1,
		math.floor(config.magazineCapacity or getMagazineCapacity(template, stats))
	)
	self.ammo = self.magazineCapacity
	self.reserveAmmo = math.max(0, math.floor(config.reserveAmmo or self.magazineCapacity * 3))

	local rawFireRate = getNumber(stats, { "fireRate", "firerate", "rateOfFire" }, 600)
	local inferredFireInterval = if rawFireRate > 10 then 60 / rawFireRate else rawFireRate
	self.fireInterval = math.max(0.01, config.fireInterval or inferredFireInterval)
	self.reloadDuration = math.max(
		0,
		config.reloadDuration or getNumber(stats, { "reloadTime", "reloadDuration" }, 4)
	)
	self.range = math.max(1, config.range or getNumber(stats, { "maxRange", "range", "range1" }, 1000))
	self.damage = math.max(0, config.damage or getNumber(stats, { "damage", "damage0", "baseDamage" }, 25))
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

function SPHController.SetStance(self: SPHController, stance: Stance): ()
	assert(stance == "Standing" or stance == "Crouching" or stance == "Proning", `Invalid stance {stance}`)
	self.stance = stance
	self.gait = nil
	self:_applyStanceHeight()
	self:_playStanceIdle()
	self:_setStateAttributes()
end

function SPHController.Aim(self: SPHController, targetPosition: Vector3): ()
	self.aimTarget = targetPosition
	self.humanoid.AutoRotate = false

	local flatTarget = Vector3.new(targetPosition.X, self.rootPart.Position.Y, targetPosition.Z)
	if (flatTarget - self.rootPart.Position).Magnitude > 0.001 then
		self.rootPart.CFrame = CFrame.lookAt(self.rootPart.Position, flatTarget)
	end

	if self.animationNames.aim then
		local aimTrack = self.weaponTracks[self.animationNames.aim]
		if not aimTrack or self.activeWeaponTrack ~= aimTrack or not aimTrack.IsPlaying then
			self:_playWeaponAnimation(self.animationNames.aim, true, Enum.AnimationPriority.Action)
		end
	end
end

function SPHController.ClearAim(self: SPHController): ()
	self.aimTarget = nil
	self.humanoid.AutoRotate = true

	local aimAnimationName = self.animationNames.aim
	local aimTrack = if aimAnimationName then self.weaponTracks[aimAnimationName] else nil
	if aimTrack and self.activeWeaponTrack == aimTrack then
		stopTrack(aimTrack)
		self.activeWeaponTrack = nil
		if self.equipped and not self.reloading then
			self:_playWeaponAnimation(self.animationNames.idle, true, Enum.AnimationPriority.Idle)
		end
	end
end

function SPHController.Equip(self: SPHController, weaponName: string?): boolean
	if self.destroyed or self.reloading then
		return false
	end

	local requestedWeapon = weaponName or self.weaponName
	if self.equipped and self.weapon and requestedWeapon == self.weaponName then
		return true
	end

	local template = resolveToolTemplate(requestedWeapon)
	if requestedWeapon ~= self.weaponName then
		self:Unequip()
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
	self:_setWeaponRigVisible(true)
	self.equipped = true
	self:_setStateAttributes()

	local track = self:_playWeaponAnimation(self.animationNames.equip, false, Enum.AnimationPriority.Action)
	if track then
		local loadedLength = waitForTrackLength(track, 2)
		local duration = if loadedLength > 0 then loadedLength else 0.5
		waitForDuration(duration, function(): boolean
			return self.destroyed or not self.equipped
		end)
	end
	if self.equipped then
		self:_playWeaponAnimation(self.animationNames.idle, true, Enum.AnimationPriority.Idle)
	end
	return self.equipped
end

function SPHController.Unequip(self: SPHController): ()
	self.equipped = false
	self.reloading = false
	stopTrack(self.activeWeaponTrack)
	self.activeWeaponTrack = nil
	self.humanoid:UnequipTools()
	if self.weapon then
		self.weapon.Parent = self.inventory
	end
	self:_clearEquippedWeaponModel()
	self:_setWeaponRigVisible(false)
	self:_showHolster()
	self:_setStateAttributes()
end

function SPHController.Fire(self: SPHController): boolean
	if self.destroyed or not self:CanFire() then
		return false
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
		self:_playWeaponAnimation(self.animationNames.fire, false, Enum.AnimationPriority.Action)
	end
	return true
end

function SPHController.Reload(self: SPHController): boolean
	if self.destroyed or not self.equipped or self.reloading then
		return false
	end
	if self.ammo >= self.magazineCapacity or self.reserveAmmo <= 0 then
		return false
	end

	self.reloading = true
	self:_setStateAttributes()
	local track = self:_playWeaponAnimation(self.animationNames.reload, false, Enum.AnimationPriority.Action)
	local duration = self.reloadDuration
	if track then
		local loadedLength = waitForTrackLength(track, 2)
		if loadedLength > 0 then
			duration = loadedLength
		end
	end

	local completed = waitForDuration(duration, function(): boolean
		return self.destroyed or not self.equipped
	end)
	if not completed then
		self.reloading = false
		self:_setStateAttributes()
		return false
	end

	local needed = self.magazineCapacity - self.ammo
	local transferred = math.min(needed, self.reserveAmmo)
	self.ammo += transferred
	self.reserveAmmo -= transferred
	self.reloading = false
	self:_setStateAttributes()
	self:_playWeaponAnimation(self.animationNames.idle, true, Enum.AnimationPriority.Idle)
	return true
end

function SPHController.Chamber(self: SPHController): boolean
	if self.destroyed or not self.equipped or self.reloading then
		return false
	end
	local track = self:_playWeaponAnimation(self.animationNames.chamber, false, Enum.AnimationPriority.Action)
	if not track then
		return false
	end
	local loadedLength = waitForTrackLength(track, 2)
	local duration = if loadedLength > 0 then loadedLength else 0.25
	return waitForDuration(duration, function(): boolean
		return self.destroyed or not self.equipped
	end)
end

function SPHController.CloseBolt(self: SPHController): boolean
	if self.destroyed or not self.equipped or self.reloading then
		return false
	end
	local track = self:_playWeaponAnimation(self.animationNames.close, false, Enum.AnimationPriority.Action)
	if not track then
		return false
	end
	local loadedLength = waitForTrackLength(track, 2)
	local duration = if loadedLength > 0 then loadedLength else 0.25
	return waitForDuration(duration, function(): boolean
		return self.destroyed or not self.equipped
	end)
end

function SPHController.SwitchFireMode(self: SPHController): boolean
	if self.destroyed or not self.equipped or self.reloading then
		return false
	end
	local track = self:_playWeaponAnimation(self.animationNames.switch, false, Enum.AnimationPriority.Action)
	if not track then
		return false
	end
	local loadedLength = waitForTrackLength(track, 2)
	local duration = if loadedLength > 0 then loadedLength else 0.25
	return waitForDuration(duration, function(): boolean
		return self.destroyed or not self.equipped
	end)
end

function SPHController.MoveTo(self: SPHController, destination: Vector3 | BasePart, gait: Gait): boolean
	if self.destroyed then
		return false
	end

	self:ClearAim()
	self.moveSerial += 1
	local serial = self.moveSerial
	local speed: number
	if gait == "Sprint" then
		self.stance = "Standing"
		speed = self.sprintSpeed
	elseif gait == "CrouchWalk" then
		self.stance = "Crouching"
		speed = self.crouchSpeed
	elseif gait == "ProneWalk" then
		self.stance = "Proning"
		speed = self.proneSpeed
	else
		assert(gait == "Walk", `Invalid gait {gait}`)
		self.stance = "Standing"
		speed = self.walkSpeed
	end

	self.gait = gait
	self:_applyStanceHeight()
	self.humanoid.WalkSpeed = speed
	self.setPathSpeed(speed)
	self:_playGaitAnimation(gait)
	self:_setStateAttributes()
	local destinationPosition = if typeof(destination) == "Instance"
		then (destination :: BasePart).Position
		else destination :: Vector3
	self.runPath(destinationPosition)

	local startedAt = os.clock()
	local reached = false
	while not self.destroyed and self.moveSerial == serial do
		local offset = self.rootPart.Position - destinationPosition
		local closeEnough = Vector3.new(offset.X, 0, offset.Z).Magnitude <= self.reachDistance
		local touchedWaypoint = if typeof(destination) == "Instance"
			then waypointContainsCharacter(destination :: BasePart, self.character)
			else closeEnough
		local reachedDestination = if typeof(destination) == "Instance" then touchedWaypoint else closeEnough
		if reachedDestination then
			reached = true
			if typeof(destination) == "Instance" then
				self.character:SetAttribute("SPHWaypointContact", (destination :: BasePart).Name)
			end
			break
		end
		if self.humanoid.Health <= 0 or os.clock() - startedAt >= self.moveTimeout then
			break
		end
		task.wait(0.1)
	end

	if self.moveSerial == serial then
		self.stopPath()
		self.gait = nil
		self:_playStanceIdle()
		self:_setStateAttributes()
	end
	return reached
end

function SPHController.StopMoving(self: SPHController): ()
	self.moveSerial += 1
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
	self:Unequip()
	self:ClearAim()
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
	self.destroyPath()
end

function SPHController.new(character: Model, config: Config?): SPHController
	local controllerConfig = config or {}
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
	local weaponRig, weaponAnimator, weaponAnimBase, weaponBaseMotor = createWeaponRig(
		character,
		assets,
		head,
		rightArm,
		leftArm
	)

	local pathfinder = NoobPath.Humanoid(character, DefaultNoobPathConfig.AgentParams, DefaultNoobPathConfig.Precise)
	pathfinder.Timeout = DefaultNoobPathConfig.Timeout
	pathfinder.Visualize = DefaultNoobPathConfig.Visualize
	pathfinder.Error:Connect(function(reason: string): ()
		character:SetAttribute("SPHPathError", reason)
		warn(`[SPHController] NoobPath error for {character.Name}: {reason}`)
	end)
	pathfinder.Trapped:Connect(function(reason: string): ()
		character:SetAttribute("SPHPathError", reason)
	end)
	pathfinder.Reached:Connect(function(): ()
		character:SetAttribute("SPHPathError", nil)
	end)

	local self = setmetatable({
		character = character,
		humanoid = humanoid,
		animator = animator,
		rootPart = rootPart,
		torso = torso,
		neckJoint = neckJoint,
		defaultNeckC1 = if neckJoint then neckJoint.C1 else nil,
		headPoseConnection = nil,
		animations = animations,
		weaponName = weaponName,
		weapon = nil,
		weaponModel = nil,
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
		walkSpeed = controllerConfig.walkSpeed or 12,
		sprintSpeed = controllerConfig.sprintSpeed or 20,
		crouchSpeed = controllerConfig.crouchSpeed or 7,
		proneSpeed = controllerConfig.proneSpeed or 3,
		reachDistance = controllerConfig.reachDistance or 2.5,
		moveTimeout = controllerConfig.moveTimeout or 30,
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
		aimTarget = nil,
		stance = "Standing" :: Stance,
		gait = nil,
		nextShotAt = 0,
		reloading = false,
		equipped = false,
		destroyed = false,
		moveSerial = 0,
		runPath = function(destination: Vector3): ()
			pathfinder:Run(destination)
		end,
		stopPath = function(): ()
			pathfinder:Stop()
		end,
		destroyPath = function(): ()
			pathfinder:Destroy()
		end,
		setPathSpeed = function(speed: number): ()
			pathfinder.Speed = speed
		end,
	}, SPHController)

	self:_configureWeaponStats(template, controllerConfig)
	self.weaponBaseMotor.C0 = self.weaponServerOffset
	self:_createInventoryTool(weaponName)
	self:_showHolster()
	self.headPoseConnection = RunService.Heartbeat:Connect(function(): ()
		if not self.destroyed then
			self:_updateHeadPose()
		end
	end)
	self:_setStateAttributes()
	return self
end

return SPHController
