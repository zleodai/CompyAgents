local NoobPathConfig = {
	Enabled = true,
	Precise = true,
	Timeout = true,
	Visualize = true,
	AgentParams = {
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentCanClimb = true,
		WaypointSpacing = 4,
		Costs = {},
		PathSettings = {
			SupportPartialPath = true,
		},
	},
}

return NoobPathConfig
