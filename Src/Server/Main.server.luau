-- !strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CompyServerScripts = ServerScriptService.CompyAgent
local CompySharedScripts = ReplicatedStorage.CompyAgent

local Config = require(CompySharedScripts.Config)

if Config.Tests.Enabled then
	local TestRunner = require(CompyServerScripts.Tests.TestRunner)
	local summary = TestRunner.RunAll()
	print(("[CompyAgent:Tests] Completed %d tests with %d failures"):format(summary.total, summary.failed))
	if summary.failed > 0 then
		error(("[CompyAgent:Tests] %d runtime tests failed"):format(summary.failed))
	end
else
	local Simulation = require(CompyServerScripts.Core.Simulation)
	local simulation = Simulation.new(Config)
	simulation:Start()

	game:BindToClose(function(): ()
		simulation:Stop()
	end)

	print("[CompyAgent] Server simulation started")
end
