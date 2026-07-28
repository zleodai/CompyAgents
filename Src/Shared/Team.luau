--!strict

local Team = {}

export type Id = string

export type Definition = {
	Color: Color3,
	SpawnOrigin: Vector3,
	SpawnSpacing: number,
	Forward: Vector3,
	Models: { string },
}

export type Registry = { [Id]: Definition }

function Team.AssertKnown(registry: Registry, teamId: Id): Definition
	assert(teamId ~= "", "Team id must not be empty")
	local definition = registry[teamId]
	assert(definition, `Unknown team {teamId}`)
	return definition
end

return Team
