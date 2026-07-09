local AgentConfig = {
	MaxHealth = 100,
	MaxAmmo = 30,
	ThinkInterval = 0.1,
	VisionInterval = 0.25,
	BlackboardUpdateInterval = 0.25,
	InfoBar = false,
	DebugRaycast = false,
	DebugTracers = true,
	DebugLog = false,
	WalkSpeed = 18,
	ModelFolderName = "CompyAgentModels",
	RootPartSize = Vector3.new(2, 2, 1),
	HeadSize = Vector3.new(1.2, 1.2, 1.2),
	HeadOffset = Vector3.new(0, 2.5, 0),
	HipHeight = 2,
	DebugTransparency = 0.35,
}

return AgentConfig
