--!strict

local NoobPathConfig = {
	Enabled = true,
	Precise = false,
	Timeout = false,
	Visualize = false,
	AgentParams = {
		AgentRadius = 3,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentCanClimb = false,
		WaypointSpacing = 12,
		Costs = {},
		PathSettings = {
			SupportPartialPath = true,
		},
	},
}

return NoobPathConfig
