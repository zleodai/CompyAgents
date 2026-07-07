--[=[
	AgentState

	Factory for the pure-data agent record used by the simulation. This module
	contains no Roblox Instance ownership so agents can later be driven by grid,
	raycast, humanoid, or custom movement adapters.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)


local AgentState = {}

function AgentState.create(id: Types.AgentId, teamId: Types.TeamId, position: Vector3, facing: Vector3?): Types.Agent
	return {
		id = id,
		teamId = teamId,

		transform = {
			position = position,
			facing = facing or Vector3.new(0, 0, -1),
		},

		stats = {
			health = 100,
			ammo = 30,
			alive = true,
		},

		decision = {
			currentGoal = nil,
			currentPlan = nil,
			currentActionIndex = 1,
			needsPlan = true,
			planningQueued = false,
			nextThinkAt = 0,
			lastPlanReason = "bootstrap",
			actionRuntime = {
				actionId = nil,
				started = false,
				startedAt = 0,
			},
		},

		movement = {
			mode = "Idle",
			destination = nil,
			path = nil,
			pathIndex = 1,
			needsPath = false,
			pathQueued = false,
			nextPathAt = 0,
			arrived = false,
		},

		combat = {
			targetId = nil,
			shouldFire = false,
			shotCompleted = false,
			lastShotAt = 0,
			lastShotOrigin = nil,
			lastShotTarget = nil,
		},

		perception = {
			visibleEnemies = {},
			lastSeenEnemies = {},
			nextSenseAt = 0,
			sensingQueued = false,
		},

		tactical = {
			inCover = false,
			suppressed = false,
		},
	}
end

return AgentState
