-- !strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CompyEvents = ServerScriptService.CompyAgent.CompyEvents
local AgentFired = CompyEvents.AgentFired

local RemoteEvents = ReplicatedStorage.RemoteEvents
local DebugPress = RemoteEvents.DebugPress

game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.MaxHealth = math.huge
		humanoid.Health = math.huge
		humanoid.WalkSpeed = 64
	end)
end)

DebugPress.OnServerEvent:Connect(function(_, position: Vector3)
	AgentFired:Fire("playerTeam", position)
end)
