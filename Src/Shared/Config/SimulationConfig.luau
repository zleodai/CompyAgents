-- !strict

local SimulationConfig = {
	DemoAgentsPerTeam = 10,
	UseStudioLevel = true,
	UseConfigSpawnsFallback = true,
	SpawnTag = "CompySpawn",
	CoverTag = "CompyCover",
	ObjectiveTag = "CompyObjective",
	RoomTag = "CompyRoom",
	DoorTag = "CompyDoor",
	VisualizationInterval = 0.1,
	MetricsInterval = 1,
}

SimulationConfig.AgentService = {
	PositionUpdateInterval = 0.05,
}
SimulationConfig.EnvironmentalService = {}
SimulationConfig.DebugService = {
	Enabled = true,
	PlannerLogsEnabled = true,
	MaxLogs = 100,
}
SimulationConfig.SoundService = {
	AgentFiredDuration = 0.1,
}

return SimulationConfig
