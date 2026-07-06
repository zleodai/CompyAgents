--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local playerScripts = player:WaitForChild("PlayerScripts")
local CompyClientScripts = playerScripts:WaitForChild("CompyAgent")
local App = require(CompyClientScripts.UI.App)

local rootContainer = Instance.new("Folder")
rootContainer.Name = "CompyAgentDebugUIRoot"
rootContainer.Parent = playerGui

local root = ReactRoblox.createRoot(rootContainer)
root:render(React.createElement(App))

script.Destroying:Connect(function(): ()
	root:unmount()
	rootContainer:Destroy()
end)
