--!strict

local AgentConfig = {
	MaxHealth = 100,
	AimReactionTime = 0.2,
	InitialMagazines = 3,
	VisionDistance = 1000,
	FailedPlanCooldown = 0.5,
	InfoBar = false,
	DebugRaycast = false,
	DebugTracers = true,
	DebugLog = false,
}

AgentConfig.FindEnemyLocation = {
	RetargetInterval = 20, --has to be atleast 1 second
	DirectionNoise = 0.75,
	FowardDistanceMin = 30,
	FowardDistanceMax = 50,
}

AgentConfig.EngageEnemy = {
	DetectionInterval = 0.1,
	RetargetInterval = 2,
	EngagementDistance = 100,
	FiringDistance = 200,
	MaxEngagingTime = 30,
}

return AgentConfig
