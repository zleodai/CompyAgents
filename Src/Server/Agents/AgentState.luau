local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Types = require(CompyServerScripts.Core.Types)

local AgentState = {}

function AgentState.create(
	id: string,
	teamId: string,
	position: Vector3,
	facing: Vector3?,
	config: Types.Config
): Types.AgentState
	return {
		id = id,
		teamId = teamId,
		alive = true,
		health = config.Agent.MaxHealth,
		ammo = config.Agent.MaxAmmo,
		position = position,
		facing = facing or Vector3.new(0, 0, -1),
		model = nil,
		humanoid = nil,
		rootPart = nil,
		head = nil,
		currentGoal = nil,
		currentActionId = nil,
		currentPlan = nil,
		currentActionIndex = 1,
		actionStarted = false,
		actionStartedAt = 0,
		needsPlan = true,
		replanReason = "spawned",
		visibleEnemies = {},
		knownEnemies = {},
		inCover = false,
		destination = nil,
		moving = false,
		arrived = false,
		targetId = nil,
		toReload = false,
		reloadEndTime = -math.huge,
		reloading = false,
		shotCompleted = false,
		lastShotAt = -math.huge,
		lastShotOrigin = nil,
		lastShotTarget = nil,
		lastRaycastAt = -math.huge,
		lastRaycastOrigin = nil,
		lastRaycastEnd = nil,
		debugGoal = "None",
		debugAction = "None",
		inDepthDebugUIActive = false,
		inDepthDebugUIText = "",
		inDepthDebugUIPlanText = "",
	}
end

return AgentState
