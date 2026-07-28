--!strict

local Enums = {}

export type Behaviour = "None" | "EngagingEnemy" | "InCover" | "CapturingObjective"
export type Movement = "Walk" | "Sprint" | "CrouchWalk" | "ProneWalk"
export type Posture = "Standing" | "Crouching" | "Proning"
export type Rifles = "AK47" | "AK12"

return Enums
