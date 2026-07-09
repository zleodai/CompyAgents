local ServerScriptService = game:GetService("ServerScriptService")
local CompyServerScripts = ServerScriptService.CompyAgent

local AgentService = require(CompyServerScripts.World.AgentService)
local Types = require(CompyServerScripts.Core.Types)

local AgentServiceTests: { Types.TestCase } = {}

table.insert(AgentServiceTests, {
	name = "AgentService lists enemy states",
	run = function(context: Types.TestContext): ()
		local service = AgentService.new()
		service:Register({
			state = {
				id = "Blue_01",
				teamId = "Blue",
				alive = true,
			},
		})
		service:Register({
			state = {
				id = "Red_01",
				teamId = "Red",
				alive = true,
			},
		})

		local enemies = service:GetEnemyStates("Blue")
		context.AssertEqual(#enemies, 1, "Blue should see one enemy")
		context.AssertEqual(enemies[1].id, "Red_01", "enemy id should match")
	end,
})

return AgentServiceTests
