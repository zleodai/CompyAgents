--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Enums = require(CompyServerScripts.Core.Enums)

local EngagingBehaviour = {}
EngagingBehaviour.__index = EngagingBehaviour

type EngagingBehaviourData = {
	started: boolean,
	params: {
		id: number,
		character: Model,
		sightedEnemyLocs: { Vector3 },
		movement: number,
		rifleAmmo: number,
		equippedRifle: number,
	},
	engageEnemy: (number, Model, Vector3, number) -> boolean,
}

export type EngagingBehaviour = typeof(setmetatable({} :: EngagingBehaviourData, EngagingBehaviour))

function EngagingBehaviour.onStartAction(self: EngagingBehaviour, _dt: number): ()
	self.params.movement = Enums.Movement.Idle
end

function EngagingBehaviour.onEndAction(self: EngagingBehaviour): ()
	self.params.movement = Enums.Movement.Idle
end

function EngagingBehaviour.Reset(self: EngagingBehaviour): ()
	if self.started then
		self:onEndAction()
	end
	self.started = false
end

function EngagingBehaviour.Progress(self: EngagingBehaviour, dt: number): ()
	if not self.started then
		self.started = true
		self:onStartAction(dt)
	end

	local targetPosition = self.params.sightedEnemyLocs[1]
	if not targetPosition or self.params.rifleAmmo <= 0 then
		return
	end

	if self.engageEnemy(self.params.id, self.params.character, targetPosition, self.params.equippedRifle) then
		self.params.rifleAmmo -= 1
	end
end

function EngagingBehaviour.Finished(self: EngagingBehaviour): boolean
	if not self.started then
		return false
	end
	return #self.params.sightedEnemyLocs == 0 or self.params.rifleAmmo <= 0
end

function EngagingBehaviour.new(
	params: {
		id: number,
		character: Model,
		sightedEnemyLocs: { Vector3 },
		movement: number,
		rifleAmmo: number,
		equippedRifle: number,
	},
	engageEnemy: (number, Model, Vector3, number) -> boolean
): EngagingBehaviour
	return setmetatable({
		started = false,
		params = params,
		engageEnemy = engageEnemy,
	}, EngagingBehaviour)
end

return EngagingBehaviour
