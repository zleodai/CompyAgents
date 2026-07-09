local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local Types = require(CompyServerScripts.Core.Types)

local TestGroups: { { Types.TestCase } } = {
	require(CompyServerScripts.Tests.GOAP.PlannerTests),
	require(CompyServerScripts.Tests.Blackboard.BlackboardStoreTests),
	require(CompyServerScripts.Tests.World.AgentServiceTests),
	require(CompyServerScripts.Tests.Agents.AgentRuntimeTests),
}

local TestRunner = {}

local function createContext(): Types.TestContext
	return {
		Assert = function(condition: boolean, message: string): ()
			if not condition then
				error(message, 2)
			end
		end,
		AssertEqual = function(actual: Types.TestValue, expected: Types.TestValue, message: string): ()
			if actual ~= expected then
				error(("%s expected=%s actual=%s"):format(message, tostring(expected), tostring(actual)), 2)
			end
		end,
	}
end

function TestRunner.RunAll(): Types.TestSummary
	local summary: Types.TestSummary = {
		total = 0,
		failed = 0,
	}

	for _, tests in ipairs(TestGroups) do
		for _, test in ipairs(tests) do
			summary.total += 1
			local ok, err = pcall(test.run, createContext())
			if not ok then
				summary.failed += 1
				warn(("[CompyAgent:Tests] %s failed: %s"):format(test.name, tostring(err)))
			end
		end
	end

	return summary
end

return TestRunner
