--!strict

local Enums = {}

Enums.Behaviour = {
	None = 1,
	[1] = "None",
	EngagingEnemy = 2,
	[2] = "EngagingEnemy",
	InCover = 3,
	[3] = "InCover",
	CapturingObjective = 4,
	[4] = "CapturingObjective",
}

Enums.Movement = {
	Walk = 1,
	[1] = "Walk",
	Sprint = 2,
	[2] = "Sprint",
	CrouchWalk = 3,
	[3] = "CrouchWalk",
	ProneWalk = 4,
	[4] = "ProneWalk",
}

Enums.Posture = {
	Standing = 1,
	[1] = "Standing",
	Crouching = 2,
	[2] = "Crouching",
	Proning = 3,
	[3] = "Proning",
}

Enums.Rifles = {
	AK47 = 1,
	[1] = "AK47",
	AK12 = 2,
	[2] = "AK12",
}

return Enums
