--!strict

local DamageSensor = {}
DamageSensor.__index = DamageSensor

type DamageSensorData = {
	id: number,
	owner: {
		health: number,
	},
	checkDamage: (number) -> number,
}

export type DamageSensor = typeof(setmetatable({} :: DamageSensorData, DamageSensor))

function DamageSensor.Sense(self: DamageSensor): ()
	local damage = math.max(0, self.checkDamage(self.id))
	self.owner.health = math.max(0, self.owner.health - damage)
end

function DamageSensor.new(owner: { health: number }, id: number, checkDamage: (number) -> number): DamageSensor
	return setmetatable({
		id = id,
		owner = owner,
		checkDamage = checkDamage,
	}, DamageSensor)
end

return DamageSensor
