--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Enums = require(CompyServerScripts.Core.Enums)

local CaptureObjectiveBehaviour = {}
CaptureObjectiveBehaviour.__index = CaptureObjectiveBehaviour

type CaptureObjectiveBehaviourData = {
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
	},
	setTarget: (Vector3?) -> (),
	reachDistance: number,
}

export type CaptureObjectiveBehaviour = typeof(setmetatable({} :: CaptureObjectiveBehaviourData, CaptureObjectiveBehaviour))

local function getTargetPosition(self: CaptureObjectiveBehaviour): Vector3?
	local behaviourParams = self.params.behaviourState.behaviourParams
	return if behaviourParams then behaviourParams.targetPosition else nil
end

local function isAtTarget(self: CaptureObjectiveBehaviour): boolean
	local targetPosition = getTargetPosition(self)
	if not targetPosition then
		return false
	end

	return (self.params.character:GetPivot().Position - targetPosition).Magnitude <= self.reachDistance
end

function CaptureObjectiveBehaviour.onStartAction(self: CaptureObjectiveBehaviour, _dt: number): ()
	self.params.movement = Enums.Movement.Sprinting
	self.setTarget(getTargetPosition(self))
end

function CaptureObjectiveBehaviour.onEndAction(self: CaptureObjectiveBehaviour): ()
	self.params.movement = Enums.Movement.Idle
	self.setTarget(nil)
end

function CaptureObjectiveBehaviour.Reset(self: CaptureObjectiveBehaviour): ()
	if self.started then
		self:onEndAction()
	end
	self.started = false
end

function CaptureObjectiveBehaviour.Progress(self: CaptureObjectiveBehaviour, dt: number): ()
	if not self.started then
		self.started = true
		self:onStartAction(dt)
	end
end

function CaptureObjectiveBehaviour.Finished(self: CaptureObjectiveBehaviour): boolean
	return self.started and (getTargetPosition(self) == nil or isAtTarget(self))
end

function CaptureObjectiveBehaviour.new(
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
	},
	setTarget: (Vector3?) -> ()
): CaptureObjectiveBehaviour
	return setmetatable({
		started = false,
		params = params,
		setTarget = setTarget,
		reachDistance = 4,
	}, CaptureObjectiveBehaviour)
end

return CaptureObjectiveBehaviour
