--!strict

local AgentConfig = {
	MaxHealth = 100,
	InitialMagazines = math.huge,
	VisionDistance = 1000,
	FailedPlanCooldown = 0.5,
	InfoBar = false,
	DebugRaycast = false,
	DebugTracers = true,
	DebugLog = false,
}

AgentConfig.ControllerConfig = {
	weaponName = "AKM",
	reserveAmmo = math.huge,
	moveTimeout = 30,
	aimSpeed = 0.4,
	speedMult = 0.75,
}

AgentConfig.FindEnemyLocation = {
	StuckCheckInterval = 1, --has to be atleast 1 second
	StuckDistance = 1,
	RetargetInterval = 20, --has to be atleast 1 second
	DirectionNoiseImpact = 0.75,
	FowardDistanceMin = 30,
	FowardDistanceMax = 200,
}

AgentConfig.EngageEnemy = {
	DetectionInterval = 0.1,
	RetargetInterval = 2,
	EngagementDistance = 100,
	FiringDistance = 200,
	MaxEngagingTime = 30,
}

return AgentConfig
