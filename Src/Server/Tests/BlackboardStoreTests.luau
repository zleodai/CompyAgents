--[=[
	BlackboardStoreTests

	Covers deterministic shared-sighting selection used by search movement.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent
local Types = require(CompyServerScripts.Core.Types)
local BlackboardStore = require(CompyServerScripts.Blackboard.BlackboardStore)

local BlackboardStoreTests: { Types.TestCase } = {}

local function createContact(agentId: Types.AgentId, confidence: number, position: Vector3): Types.PerceptionContact
	return {
		agentId = agentId,
		teamId = "Red",
		position = position,
		confidence = confidence,
		lastSeenAt = 0,
	}
end

table.insert(BlackboardStoreTests, {
	name = "BlackboardStore chooses enemy sightings deterministically",
	run = function(context: Types.TestContext): ()
		local blackboard = BlackboardStore.new("Blue")

		blackboard:RecordEnemySighting(createContact("Red_02", 1, Vector3.new(2, 0, 0)), 10)
		blackboard:RecordEnemySighting(createContact("Red_01", 1, Vector3.new(1, 0, 0)), 10)

		local best = blackboard:GetBestEnemySighting()
		context.Assert(best ~= nil and best.agentId == "Red_01", "equal sightings should use stable agent-id tie break")

		blackboard:RecordEnemySighting(createContact("Red_03", 0.5, Vector3.new(3, 0, 0)), 11)
		best = blackboard:GetBestEnemySighting()
		context.Assert(best ~= nil and best.agentId == "Red_01", "higher confidence should beat newer low confidence")

		blackboard:RecordEnemySighting(createContact("Red_04", 1, Vector3.new(4, 0, 0)), 12)
		best = blackboard:GetBestEnemySighting()
		context.Assert(best ~= nil and best.agentId == "Red_04", "newer equal-confidence sighting should win")
	end,
})

return BlackboardStoreTests
