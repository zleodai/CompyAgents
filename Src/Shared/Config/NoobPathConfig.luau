--!strict

local NoobPathConfig = {
	Enabled = true,
	Precise = false,
	Timeout = true,
	Visualize = false,
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
