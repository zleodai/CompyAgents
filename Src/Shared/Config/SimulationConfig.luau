-- !strict

local SimulationConfig = {
	DemoAgentsPerTeam = 40,
	TargetAgentsPerTeam = 20,
	UseStudioLevel = true,
	UseConfigSpawnsFallback = true,
	SpawnTag = "CompySpawn",
	CoverTag = "CompyCover",
	ObjectiveTag = "CompyObjective",
	VisualizationInterval = 0.1,
	MetricsInterval = 1,
}

SimulationConfig.AgentService = {
	PositionUpdateInterval = 0.1,
}
SimulationConfig.EnvironmentalService = {}

return SimulationConfig
