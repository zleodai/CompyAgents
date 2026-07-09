--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DebugRemoteEvents = {}

DebugRemoteEvents.Names = {
	PlaybackToggled = "DebugPlaybackToggled",
	SpeedDecreased = "DebugSpeedDecreased",
	SpeedIncreased = "DebugSpeedIncreased",
	SetAgentInDepthDebugActive = "DebugSetAgentInDepthDebugActive",
}

local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")

local function getRemoteEvent(name: string): RemoteEvent
	local remote = remoteEventsFolder:WaitForChild(name)
	assert(remote:IsA("RemoteEvent"), `{name} must be a RemoteEvent`)

	return remote
end

function DebugRemoteEvents.firePlaybackToggled(isPaused: boolean): ()
	getRemoteEvent(DebugRemoteEvents.Names.PlaybackToggled):FireServer(isPaused)
end

function DebugRemoteEvents.fireSpeedDecreased(speedScale: number): ()
	getRemoteEvent(DebugRemoteEvents.Names.SpeedDecreased):FireServer(speedScale)
end

function DebugRemoteEvents.fireSpeedIncreased(speedScale: number): ()
	getRemoteEvent(DebugRemoteEvents.Names.SpeedIncreased):FireServer(speedScale)
end

function DebugRemoteEvents.fireAgentInDepthDebugActiveChanged(agentId: string, isActive: boolean): ()
	getRemoteEvent(DebugRemoteEvents.Names.SetAgentInDepthDebugActive):FireServer(agentId, isActive)
end

return DebugRemoteEvents
