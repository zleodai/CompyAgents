--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CompySharedScripts = ReplicatedStorage.CompyAgent

local Team = require(CompySharedScripts.Team)

local TeamConfig: Team.Registry = {
	Blue = {
		Color = Color3.fromRGB(55, 125, 255),
		SpawnOrigin = Vector3.new(-20, 0, 0),
		SpawnSpacing = 12,
		Forward = Vector3.new(1, 0, 0),
		Models = { "Doge" },
	},
	Red = {
		Color = Color3.fromRGB(235, 70, 70),
		SpawnOrigin = Vector3.new(20, 0, 0),
		SpawnSpacing = 12,
		Forward = Vector3.new(-1, 0, 0),
		Models = { "Dak" },
	},
}

return TeamConfig
