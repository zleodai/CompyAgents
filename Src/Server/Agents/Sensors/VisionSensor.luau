--!strict

local VisionSensor = {}
VisionSensor.__index = VisionSensor

type VisionSensorData = {
	fovX: number,
	fovY: number,
	distance: number,
	id: number,
	character: Model,
	owner: {
		sightedEnemyLocs: { Vector3 },
		sightedObjectiveLocs: { Vector3 },
		sightedCrouchCoverLocs: { Vector3 },
		sightedProneCoverLocs: { Vector3 },
	},
}

export type VisionSensor = typeof(setmetatable({} :: VisionSensorData, VisionSensor))

function VisionSensor.Sense(self: VisionSensor): ()
	-- local result = self.senseWorld(self.id, self.character, self.fovX, self.fovY, self.distance)
	-- self.owner.sightedEnemyLocs = table.clone(result.enemyLocations)
	-- self.owner.sightedObjectiveLocs = table.clone(result.objectiveLocations)
	-- self.owner.sightedCrouchCoverLocs = table.clone(result.crouchCoverLocations)
	-- self.owner.sightedProneCoverLocs = table.clone(result.proneCoverLocations)
end

function VisionSensor.new(
	owner: {
		sightedEnemyLocs: { Vector3 },
		sightedObjectiveLocs: { Vector3 },
		sightedCrouchCoverLocs: { Vector3 },
		sightedProneCoverLocs: { Vector3 },
	},
	id: number,
	character: Model,
	fovX: number,
	fovY: number,
	distance: number
): VisionSensor
	return setmetatable({
		fovX = fovX,
		fovY = fovY,
		distance = distance,
		id = id,
		character = character,
		owner = owner,
	}, VisionSensor)
end

function VisionSensor.blank(): VisionSensor
	return setmetatable({
		fovX = 0,
		fovY = 0,
		distance = 0,
		id = 0,
		character = nil,
		owner = {},
	}, VisionSensor)
end

return VisionSensor
