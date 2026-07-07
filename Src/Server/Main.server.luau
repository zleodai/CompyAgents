--[=[
	Bootstraps the CompyAgent server simulation.

	This script is the only server Script entrypoint. It creates the data-first
	simulation and advances it from RunService.Heartbeat.
]=]

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Config = require(CompyServerScripts.Core.Config)
local Types = require(CompyServerScripts.Core.Types)

if Config.Tests.Enabled then
	local TestRunner = require(CompyServerScripts.Tests.TestRunner)
	local summary: Types.TestSummary = TestRunner.RunAll()
	print(("[CompyAgent:Tests] Completed %d tests with %d failures"):format(summary.total, summary.failed))
else
	local Simulation = require(CompyServerScripts.Core.Simulation)
	local simulation: Types.Simulation = Simulation.new()
	simulation:Start()

	RunService.Heartbeat:Connect(function(deltaTime: number): ()
		simulation:Step(deltaTime)
	end)

	print("[CompyAgent] Server simulation started")
end
