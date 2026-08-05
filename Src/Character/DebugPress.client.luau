local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local RemoteEvents = ReplicatedStorage.RemoteEvents
local DebugPress = RemoteEvents.DebugPress

local player = Players.LocalPlayer
local playerChar = player.Character or player.CharacterAdded:Wait()
local playerHead = playerChar:WaitForChild("Head") :: BasePart

UserInputService.InputBegan:Connect(function(input, _)
	if input.KeyCode == Enum.KeyCode.F then
		DebugPress:FireServer(playerHead.Position)
	end
end)
