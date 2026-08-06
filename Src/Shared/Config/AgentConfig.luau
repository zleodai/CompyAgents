--!strict

local AgentConfig = {
	MaxHealth = 150,
	InitialMagazines = math.huge,

	MemoryMergeDist = 10,
	MemoryFadeTime = 5,

	MinimumBraveryForBrave = 30,
	BraveryIncreaseRate = 1,

	CoverMaxDistance = 50,
	CoverMaxAngleDiff = 45,

	VisionDistance = 1000,
	VisionAngle = 80,

	SoundNoise = 20, --CANNOT BE GREATER THAN SoundClearDistance
	SoundClearDistance = 25,

	HearingDistance = 100,
	HearingFadeTime = 10,

	FailedPlanCooldown = 0.5,
	InfoBar = false,
	DebugRaycast = false,
	DebugTracers = true,
	DebugLog = false,
}

AgentConfig.ControllerConfig = {
	weaponName = "AKM",
	weaponAccuracy = 0.95, -- 0 - 1 scale
	reserveAmmo = math.huge,
	moveTimeout = 30,
	aimSpeed = 2,
	speedMult = 1,
	sprintSpeedMult = 1,
}

AgentConfig.FindEnemyLocation = {
	StuckCheckInterval = 1, --has to be atleast 1 second
	StuckDistance = 1,
	RetargetInterval = 20, --has to be atleast 1 second
	DirectionNoiseImpact = 0.8,
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

AgentConfig.InvestigateEnemyFiring = {
	MaxSoundAngleDiff = 30,
}

AgentConfig.TakeCover = {
	ReachCoverXZDist = 2,
}

return AgentConfig
