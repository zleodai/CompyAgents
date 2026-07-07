--[=[
	TestRunner

	Lightweight server-side test runner for Roblox-only modules. Main.server runs
	this instead of Simulation when Config.Tests.Enabled is true.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Config = require(CompyServerScripts.Core.Config)
local Types = require(CompyServerScripts.Core.Types)

local TestRunner = {}

local TEST_MODULES: { { Types.TestCase } } = {
	require(CompyServerScripts.Tests.BudgetQueueTests),
	require(CompyServerScripts.Tests.SchedulerTests),
	require(CompyServerScripts.Tests.GOAPPlannerTests),
	require(CompyServerScripts.Tests.BlackboardStoreTests),
	require(CompyServerScripts.Tests.StudioWorldRegistryTests),
	require(CompyServerScripts.Tests.AgentModelTests),
	require(CompyServerScripts.Tests.RaycastSensorTests),
	require(CompyServerScripts.Tests.NoobPathMovementTests),
	require(CompyServerScripts.Tests.VisualizationSystemTests),
}

local function formatValue(value: Types.TestValue): string
	if value == nil then
		return "nil"
	end

	return tostring(value)
end

local function createContext(): Types.TestContext
	return {
		Assert = function(condition: boolean, message: string): ()
			if not condition then
				error(message, 2)
			end
		end,

		AssertEqual = function(actual: Types.TestValue, expected: Types.TestValue, message: string): ()
			if actual ~= expected then
				error(("%s expected=%s actual=%s"):format(message, formatValue(expected), formatValue(actual)), 2)
			end
		end,

		AssertActionSequence = function(actual: { Types.ActionId }, expected: { Types.ActionId }, message: string): ()
			if #actual ~= #expected then
				error(
					("%s expected=[%s] actual=[%s]"):format(
						message,
						table.concat(expected, ","),
						table.concat(actual, ",")
					),
					2
				)
			end

			for index, expectedActionId in ipairs(expected) do
				if actual[index] ~= expectedActionId then
					error(
						("%s expected=[%s] actual=[%s]"):format(
							message,
							table.concat(expected, ","),
							table.concat(actual, ",")
						),
						2
					)
				end
			end
		end,
	}
end

local function flattenTests(): { Types.TestCase }
	local tests: { Types.TestCase } = {}

	for _, moduleTests in ipairs(TEST_MODULES) do
		for _, testCase in ipairs(moduleTests) do
			table.insert(tests, testCase)
		end
	end

	return tests
end

function TestRunner.RunAll(): Types.TestSummary
	local context = createContext()
	local tests = flattenTests()
	local summary: Types.TestSummary = {
		total = #tests,
		passed = 0,
		failed = 0,
		failures = {},
	}

	print(("[CompyAgent:Tests] Running %d tests"):format(summary.total))

	for _, testCase in ipairs(tests) do
		local ok, failureMessage = pcall(testCase.run, context)

		if ok then
			summary.passed = summary.passed + 1
			if Config.Tests.Verbose then
				print(("[CompyAgent:Tests] PASS %s"):format(testCase.name))
			end
		else
			local message = tostring(failureMessage)
			summary.failed = summary.failed + 1
			table.insert(summary.failures, {
				name = testCase.name,
				message = message,
			})
			warn(("[CompyAgent:Tests] FAIL %s: %s"):format(testCase.name, message))

			if Config.Tests.FailFast then
				error(("[CompyAgent:Tests] Stopped after first failure: %s"):format(testCase.name), 0)
			end
		end
	end

	print(("[CompyAgent:Tests] Summary: %d passed, %d failed"):format(summary.passed, summary.failed))

	if summary.failed > 0 then
		error(("[CompyAgent:Tests] %d test(s) failed"):format(summary.failed), 0)
	end

	return summary
end

return TestRunner
