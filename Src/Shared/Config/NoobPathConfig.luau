--!strict

local NoobPathConfig = {
	Enabled = true,
	Precise = true,
	Timeout = true,
	Visualize = false,
	AgentParams = {
		AgentRadius = 3,
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
