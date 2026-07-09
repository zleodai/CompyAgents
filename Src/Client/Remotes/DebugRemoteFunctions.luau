--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DebugRemoteFunctions = {}

DebugRemoteFunctions.Names = {
	AverageFrameMS = "DebugAverageFrameMS",
	AgentInDepthDebugText = "DebugGetAgentInDepthDebugText",
}

local REMOTE_FUNCTION_REQUESTS_ENABLED = true
local remotesFolder = ReplicatedStorage:WaitForChild("RemoteEvents")

export type AverageFrameMSHandler = (number?) -> ()

local function getRemoteFunction(name: string): RemoteFunction
	local remote = remotesFolder:WaitForChild(name)
	assert(remote:IsA("RemoteFunction"), `{name} must be a RemoteFunction`)

	return remote
end

function DebugRemoteFunctions.getAverageFrameMS(): number?
	if not REMOTE_FUNCTION_REQUESTS_ENABLED then
		return nil
	end

	local didInvoke, result = pcall(function()
		return getRemoteFunction(DebugRemoteFunctions.Names.AverageFrameMS):InvokeServer()
	end)

	if didInvoke and type(result) == "number" then
		return result
	end

	return nil
end

function DebugRemoteFunctions.requestAverageFrameMS(onResult: AverageFrameMSHandler): () -> ()
	local isActive = true

	if not REMOTE_FUNCTION_REQUESTS_ENABLED then
		task.defer(function(): ()
			if isActive then
				onResult(nil)
			end
		end)

		return function(): ()
			isActive = false
		end
	end

	task.spawn(function(): ()
		if isActive then
			onResult(DebugRemoteFunctions.getAverageFrameMS())
		end
	end)

	return function(): ()
		isActive = false
	end
end

function DebugRemoteFunctions.getAgentInDepthDebugText(agentId: string): string
	local didInvoke, result = pcall(function()
		return getRemoteFunction(DebugRemoteFunctions.Names.AgentInDepthDebugText):InvokeServer(agentId)
	end)

	if didInvoke and type(result) == "string" then
		return result
	end

	return ""
end

return DebugRemoteFunctions
