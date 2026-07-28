--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local CompyServerScripts = ServerScriptService.CompyAgent

local TestGroups = {
	require(CompyServerScripts.Tests.Agents.PlannerModuleTests),
	require(CompyServerScripts.Tests.World.AgentServiceTests),
	require(CompyServerScripts.Tests.Core.SimulationIntegrationTests),
}

type TestContext = {
	Assert: (condition: boolean, message: string) -> (),
	AssertEqual: (actual: any, expected: any, message: string) -> (),
	AssertNear: (actual: number, expected: number, tolerance: number, message: string) -> (),
	AssertThrows: (callback: () -> (), message: string) -> (),
}

type TestCase = {
	name: string,
	run: (TestContext) -> (),
}

local TestRunner = {}

local function createContext(): TestContext
	return {
		Assert = function(condition: boolean, message: string): ()
			if not condition then
				error(message, 2)
			end
		end,
		AssertEqual = function(actual: any, expected: any, message: string): ()
			if actual ~= expected then
				error(("%s expected=%s actual=%s"):format(message, tostring(expected), tostring(actual)), 2)
			end
		end,
		AssertNear = function(actual: number, expected: number, tolerance: number, message: string): ()
			if math.abs(actual - expected) > tolerance then
				error(("%s expected=%.6f actual=%.6f tolerance=%.6f"):format(message, expected, actual, tolerance), 2)
			end
		end,
		AssertThrows = function(callback: () -> (), message: string): ()
			local succeeded = pcall(callback)
			if succeeded then
				error(message, 2)
			end
		end,
	}
end

function TestRunner.RunAll(): { total: number, failed: number }
	local summary = {
		total = 0,
		failed = 0,
	}

	for _, tests: { TestCase } in ipairs(TestGroups) do
		for _, test in ipairs(tests) do
			summary.total += 1
			local succeeded, testError = pcall(test.run, createContext())
			if succeeded then
				print(("[CompyAgent:Tests] PASS %s"):format(test.name))
			else
				summary.failed += 1
				warn(("[CompyAgent:Tests] FAIL %s: %s"):format(test.name, tostring(testError)))
			end
		end
	end

	return summary
end

return TestRunner
