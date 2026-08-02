-- !strict

local SimulationConfig = {
	DemoAgentsPerTeam = 5,
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
	PositionUpdateInterval = 0.1,
}
SimulationConfig.EnvironmentalService = {}
SimulationConfig.DebugService = {
	Enabled = true,
	PlannerLogsEnabled = true,
	MaxLogs = 100,
}

return SimulationConfig
