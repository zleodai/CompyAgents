--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Enums = require(CompyServerScripts.Core.Enums)

local TakeCoverBehaviour = {}
TakeCoverBehaviour.__index = TakeCoverBehaviour

type TakeCoverBehaviourData = {
	started: boolean,
	params: {
		character: Model,
		behaviourState: {
			behaviour: number,
			behaviourParams: {
				targetPosition: Vector3?,
				posture: number?,
			}?,
		},
		movement: number,
		posture: number,
	},
	setTarget: (Vector3?) -> (),
	reachDistance: number,
}

export type TakeCoverBehaviour = typeof(setmetatable({} :: TakeCoverBehaviourData, TakeCoverBehaviour))

local function getTargetPosition(self: TakeCoverBehaviour): Vector3?
	local behaviourParams = self.params.behaviourState.behaviourParams
	return if behaviourParams then behaviourParams.targetPosition else nil
end

local function isAtTarget(self: TakeCoverBehaviour): boolean
	local targetPosition = getTargetPosition(self)
	if not targetPosition then
		return false
	end

	return (self.params.character:GetPivot().Position - targetPosition).Magnitude <= self.reachDistance
end

function TakeCoverBehaviour.onStartAction(self: TakeCoverBehaviour, _dt: number): ()
	self.params.movement = Enums.Movement.Sprinting
	self.setTarget(getTargetPosition(self))
end

function TakeCoverBehaviour.onEndAction(self: TakeCoverBehaviour): ()
	if isAtTarget(self) then
		local behaviourParams = self.params.behaviourState.behaviourParams
		if behaviourParams and behaviourParams.posture then
			self.params.posture = behaviourParams.posture
		end
	end

	self.params.movement = Enums.Movement.Idle
	self.setTarget(nil)
end

function TakeCoverBehaviour.Reset(self: TakeCoverBehaviour): ()
	if self.started then
		self:onEndAction()
	end
	self.started = false
end

function TakeCoverBehaviour.Progress(self: TakeCoverBehaviour, dt: number): ()
	if not self.started then
		self.started = true
		self:onStartAction(dt)
	end
end

function TakeCoverBehaviour.Finished(self: TakeCoverBehaviour): boolean
	return self.started and (getTargetPosition(self) == nil or isAtTarget(self))
end

function TakeCoverBehaviour.new(
	params: {
		character: Model,
		behaviourState: {
			behaviour: number,
			behaviourParams: {
				targetPosition: Vector3?,
				posture: number?,
			}?,
		},
		movement: number,
		posture: number,
	},
	setTarget: (Vector3?) -> ()
): TakeCoverBehaviour
	return setmetatable({
		started = false,
		params = params,
		setTarget = setTarget,
		reachDistance = 3,
	}, TakeCoverBehaviour)
end

return TakeCoverBehaviour
