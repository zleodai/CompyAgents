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
	senseWorld: (number, Model, number, number, number) -> {
		enemyLocations: { Vector3 },
		objectiveLocations: { Vector3 },
		crouchCoverLocations: { Vector3 },
		proneCoverLocations: { Vector3 },
	},
}

export type VisionSensor = typeof(setmetatable({} :: VisionSensorData, VisionSensor))

function VisionSensor.Sense(self: VisionSensor): ()
	local result = self.senseWorld(self.id, self.character, self.fovX, self.fovY, self.distance)
	self.owner.sightedEnemyLocs = table.clone(result.enemyLocations)
	self.owner.sightedObjectiveLocs = table.clone(result.objectiveLocations)
	self.owner.sightedCrouchCoverLocs = table.clone(result.crouchCoverLocations)
	self.owner.sightedProneCoverLocs = table.clone(result.proneCoverLocations)
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
	distance: number,
	senseWorld: (number, Model, number, number, number) -> {
		enemyLocations: { Vector3 },
		objectiveLocations: { Vector3 },
		crouchCoverLocations: { Vector3 },
		proneCoverLocations: { Vector3 },
	}
): VisionSensor
	return setmetatable({
		fovX = fovX,
		fovY = fovY,
		distance = distance,
		id = id,
		character = character,
		owner = owner,
		senseWorld = senseWorld,
	}, VisionSensor)
end

return VisionSensor
