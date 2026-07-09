local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local BlackboardStore = require(CompyServerScripts.Blackboard.BlackboardStore)
local Types = require(CompyServerScripts.Core.Types)

local BlackboardStoreTests: { Types.TestCase } = {}

table.insert(BlackboardStoreTests, {
	name = "Blackboard chooses enemy sightings deterministically",
	run = function(context: Types.TestContext): ()
		local blackboard = BlackboardStore.new("Blue")
		blackboard:RecordEnemySighting("Red_02", Vector3.new(2, 0, 0), 1, true, 1)
		blackboard:RecordEnemySighting("Red_01", Vector3.new(1, 0, 0), 1, true, 1)

		local best = blackboard:GetBestEnemySighting()
		context.Assert(best ~= nil, "best sighting should exist")
		context.AssertEqual(best.agentId, "Red_01", "tie should choose deterministic agent id")
	end,
})

table.insert(BlackboardStoreTests, {
	name = "Blackboard reservations reject conflicting owners",
	run = function(context: Types.TestContext): ()
		local blackboard = BlackboardStore.new("Blue")
		context.Assert(blackboard:Reserve("cover:a", "Blue_01", 1, 5), "first owner should reserve")
		context.Assert(not blackboard:Reserve("cover:a", "Blue_02", 2, 5), "second owner should be rejected")
		context.Assert(blackboard:Reserve("cover:a", "Blue_02", 7, 5), "expired reservation should be reusable")
	end,
})

return BlackboardStoreTests
