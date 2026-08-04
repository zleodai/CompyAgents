--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CompySharedScripts = ReplicatedStorage.CompyAgent

local Config = {
	Agent = require(CompySharedScripts.Config.AgentConfig),
	Cadence = require(CompySharedScripts.Config.CadenceConfig),
	NoobPath = require(CompySharedScripts.Config.NoobPathConfig),
	Simulation = require(CompySharedScripts.Config.SimulationConfig),
	Teams = require(CompySharedScripts.Config.TeamConfig),
	Tests = require(CompySharedScripts.Config.TestConfig),
}

return Config
