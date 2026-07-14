--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CompySharedScripts = ReplicatedStorage.CompyAgent

local Config = {
	Agent = require(CompySharedScripts.Config.AgentConfig),
	Blackboard = require(CompySharedScripts.Config.BlackboardConfig),
	Cadence = require(CompySharedScripts.Config.CadenceConfig),
	Combat = require(CompySharedScripts.Config.CombatConfig),
	NoobPath = require(CompySharedScripts.Config.NoobPathConfig),
	Simulation = require(CompySharedScripts.Config.SimulationConfig),
	Teams = require(CompySharedScripts.Config.TeamConfig),
	Tests = require(CompySharedScripts.Config.TestConfig),
}

return Config
