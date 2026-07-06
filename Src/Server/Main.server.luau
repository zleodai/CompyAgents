--[=[
	Bootstraps the CompyAgent server simulation.

	This script is the only server Script entrypoint. It creates the data-first
	simulation and advances it from RunService.Heartbeat.
]=]

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)
local Simulation = require(CompyServerScripts.Core.Simulation)

local simulation: Types.Simulation = Simulation.new()
simulation:Start()

RunService.Heartbeat:Connect(function(deltaTime: number): ()
	simulation:Step(deltaTime)
end)

print("[CompyAgent] Server simulation started")
