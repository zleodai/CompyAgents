--!strict

local NoobPathConfig = {
	Enabled = true,
	Precise = false,
	Timeout = false,
	Visualize = true,
	AgentParams = {
		AgentRadius = 3,
		AgentHeight = 5,
		AgentCanJump = false,
		AgentCanClimb = false,
		WaypointSpacing = 12,
		Costs = {},
		PathSettings = {
			SupportPartialPath = true,
		},
	},
}

return NoobPathConfig
