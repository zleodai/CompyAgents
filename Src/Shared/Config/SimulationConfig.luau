-- !strict

local SimulationConfig = {
	DemoAgentsPerTeam = 1,
	TargetAgentsPerTeam = 20,
	UseStudioLevel = true,
	UseConfigSpawnsFallback = true,
	SpawnTag = "CompySpawn",
	CoverTag = "CompyCover",
	ObjectiveTag = "CompyObjective",
	HumanoidTag = "CompyHumanoid",
	GeneratedModelFolderName = "CompyAgentModels",
	VisualizationInterval = 0.1,
	MetricsInterval = 1,
}

return SimulationConfig
